import Foundation
import AppKit
import ImageIO
import UniformTypeIdentifiers

@MainActor
final class UploadService: ObservableObject {
    enum JobState: Equatable {
        case uploading
        case processing
        case done(Receipt)
        case failed(String)
    }

    struct Job: Identifiable, Equatable {
        let id: String
        var receiptId: String
        var filename: String
        var state: JobState
        var startedAt: Date
    }

    @Published private(set) var jobs: [Job] = []

    private var client: APIClient?
    private var store: ReceiptStore?
    private var pollingTask: Task<Void, Never>?

    private static let persistKey = "UploadService.pendingJobs.v1"
    private static let pollInterval: UInt64 = 5_000_000_000

    func attach(client: APIClient, store: ReceiptStore) {
        self.client = client
        self.store = store
        loadPersisted()
        startPollingIfNeeded()
    }

    // MARK: - Submit

    func submit(fileURL: URL, notes: String?) {
        guard let client else { return }
        let tempId = "temp-" + UUID().uuidString
        let filename = fileURL.lastPathComponent
        let placeholder = Job(id: tempId, receiptId: "", filename: filename,
                              state: .uploading, startedAt: Date())
        jobs.insert(placeholder, at: 0)

        Task { [weak self] in
            guard let self else { return }
            do {
                let (data, fname, mime) = try UploadService.prepareImage(url: fileURL)
                let resp = try await client.uploadReceipt(
                    imageData: data, filename: fname, mimeType: mime, notes: notes
                )
                if let idx = self.jobs.firstIndex(where: { $0.id == tempId }) {
                    self.jobs[idx] = Job(id: resp.jobId, receiptId: resp.receiptId,
                                         filename: filename, state: .processing,
                                         startedAt: Date())
                }
                self.persist()
                self.startPollingIfNeeded()
            } catch {
                let msg = (error as? LocalizedError)?.errorDescription ?? "\(error)"
                if let idx = self.jobs.firstIndex(where: { $0.id == tempId }) {
                    self.jobs[idx].state = .failed(msg)
                }
            }
        }
    }

    func dismiss(_ jobId: String) {
        jobs.removeAll { $0.id == jobId }
        persist()
    }

    func dismissAllFinished() {
        jobs.removeAll {
            if case .done = $0.state { return true }
            if case .failed = $0.state { return true }
            return false
        }
        persist()
    }

    // MARK: - Polling

    private var hasProcessingJobs: Bool {
        jobs.contains { if case .processing = $0.state { return true } else { return false } }
    }

    private func startPollingIfNeeded() {
        guard pollingTask == nil, hasProcessingJobs else { return }
        pollingTask = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                guard let self else { return }
                if !self.hasProcessingJobs {
                    self.pollingTask = nil
                    return
                }
                await self.pollOnce()
                try? await Task.sleep(nanoseconds: UploadService.pollInterval)
            }
        }
    }

    private func pollOnce() async {
        guard let client, let store else { return }
        let active = jobs.filter {
            if case .processing = $0.state { return true } else { return false }
        }
        var didFinish = false
        for job in active {
            do {
                let status = try await client.job(job.id)
                switch status.status {
                case "done":
                    let r = try await client.getReceipt(job.receiptId)
                    if let idx = jobs.firstIndex(where: { $0.id == job.id }) {
                        jobs[idx].state = .done(r)
                    }
                    didFinish = true
                    scheduleAutoDismiss(jobId: job.id, delay: 6)
                case "error":
                    if let idx = jobs.firstIndex(where: { $0.id == job.id }) {
                        jobs[idx].state = .failed(status.error ?? "Processing failed")
                    }
                    didFinish = true
                default:
                    break
                }
            } catch {
                // transient — keep trying next tick
            }
        }
        if didFinish {
            await store.refreshAll()
            persist()
        }
    }

    private func scheduleAutoDismiss(jobId: String, delay: UInt64) {
        Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: delay * 1_000_000_000)
            self?.jobs.removeAll { $0.id == jobId }
            self?.persist()
        }
    }

    // MARK: - Persistence (survives app relaunch)

    private struct Persisted: Codable {
        let jobId: String
        let receiptId: String
        let filename: String
    }

    private func persist() {
        let pending: [Persisted] = jobs.compactMap { j in
            guard case .processing = j.state else { return nil }
            return Persisted(jobId: j.id, receiptId: j.receiptId, filename: j.filename)
        }
        let data = (try? JSONEncoder().encode(pending)) ?? Data()
        UserDefaults.standard.set(data, forKey: Self.persistKey)
    }

    private func loadPersisted() {
        guard let data = UserDefaults.standard.data(forKey: Self.persistKey),
              let items = try? JSONDecoder().decode([Persisted].self, from: data) else { return }
        let resumed = items.map {
            Job(id: $0.jobId, receiptId: $0.receiptId, filename: $0.filename,
                state: .processing, startedAt: Date())
        }
        // Merge, avoiding duplicates
        for j in resumed where !jobs.contains(where: { $0.id == j.id }) {
            jobs.append(j)
        }
    }

    // MARK: - Image preparation (compression, HEIC → JPEG)

    static func prepareImage(url: URL) throws -> (Data, String, String) {
        let raw = try Data(contentsOf: url)
        guard let src = CGImageSourceCreateWithData(raw as CFData, nil) else {
            throw APIError.badResponse(0, "Cannot read image")
        }
        let opts: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceThumbnailMaxPixelSize: 2048,
            kCGImageSourceCreateThumbnailWithTransform: true,
        ]
        guard let img = CGImageSourceCreateThumbnailAtIndex(src, 0, opts as CFDictionary) else {
            throw APIError.badResponse(0, "Cannot decode image")
        }
        let out = NSMutableData()
        guard let dest = CGImageDestinationCreateWithData(
            out, UTType.jpeg.identifier as CFString, 1, nil
        ) else {
            throw APIError.badResponse(0, "Cannot create JPEG encoder")
        }
        CGImageDestinationAddImage(dest, img, [
            kCGImageDestinationLossyCompressionQuality: 0.85
        ] as CFDictionary)
        guard CGImageDestinationFinalize(dest) else {
            throw APIError.badResponse(0, "JPEG encode failed")
        }
        let base = url.deletingPathExtension().lastPathComponent
        return (out as Data, base + ".jpg", "image/jpeg")
    }
}
