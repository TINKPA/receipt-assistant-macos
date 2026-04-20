//
//  UploadService.swift
//
//  Async upload pipeline against the v1 ingest API:
//      submit(fileURL) →  POST /v1/ingest/batch (one-file batch)
//                      →  poll GET /v1/ingests/{id} until terminal
//      done           =  ingest classified + extracted; produced docId
//                        and possibly a draft transactionId surface in
//                        the toast for review
//
//  The old single-receipt receiptId is gone — what we now have is a
//  triple (batchId, ingestId, optional documentId). For the menu-bar
//  drop UX we treat a "single-file batch" as the unit of work.
//

import Foundation
import AppKit
import ImageIO
import UniformTypeIdentifiers

@MainActor
final class UploadService: ObservableObject {
    enum JobState: Equatable {
        case uploading
        case processing
        case done(documentId: String?, transactionId: String?)
        case failed(String)
    }

    struct Job: Identifiable, Equatable {
        let id: String              // ingestId once known; temp UUID before
        var batchId: String
        var filename: String
        var state: JobState
        var startedAt: Date
    }

    @Published private(set) var jobs: [Job] = []

    private var client: APIClient?
    private var store: ReceiptStore?
    private var pollingTask: Task<Void, Never>?

    private static let persistKey = "UploadService.pendingJobs.v2"
    private static let pollInterval: UInt64 = 3_000_000_000

    func attach(client: APIClient, store: ReceiptStore) {
        self.client = client
        self.store = store
        loadPersisted()
        startPollingIfNeeded()
    }

    // MARK: - Submit

    func submit(fileURL: URL, notes: String? = nil) {
        guard let client else { return }
        let tempId = "temp-" + UUID().uuidString
        let filename = fileURL.lastPathComponent
        let placeholder = Job(id: tempId, batchId: "",
                              filename: filename,
                              state: .uploading, startedAt: Date())
        jobs.insert(placeholder, at: 0)

        Task { [weak self] in
            guard let self else { return }
            do {
                let (data, fname, mime) = try UploadService.prepareImage(url: fileURL)
                let resp = try await client.uploadOne(
                    imageData: data, filename: fname, mimeType: mime
                )
                guard let item = resp.items.first else {
                    throw APIError.http(0, "Empty batch response")
                }
                if let idx = self.jobs.firstIndex(where: { $0.id == tempId }) {
                    self.jobs[idx] = Job(
                        id: item.ingestId,
                        batchId: resp.batchId,
                        filename: filename,
                        state: .processing,
                        startedAt: Date()
                    )
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
                let ingest = try await client.getIngest(job.id)
                switch ingest.status {
                case .done:
                    let docId = ingest.produced?.documentIds?.first
                    let txId = ingest.produced?.transactionIds?.first
                    if let idx = jobs.firstIndex(where: { $0.id == job.id }) {
                        jobs[idx].state = .done(documentId: docId, transactionId: txId)
                    }
                    didFinish = true
                    scheduleAutoDismiss(jobId: job.id, delay: 8)
                case .error, .unsupported:
                    if let idx = jobs.firstIndex(where: { $0.id == job.id }) {
                        let msg = ingest.error ?? "Extraction failed"
                        jobs[idx].state = .failed(msg)
                    }
                    didFinish = true
                case .queued, .processing:
                    break
                }
            } catch {
                // Transient — try again next tick
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
        let ingestId: String
        let batchId: String
        let filename: String
    }

    private func persist() {
        let pending: [Persisted] = jobs.compactMap { j in
            guard case .processing = j.state else { return nil }
            return Persisted(ingestId: j.id, batchId: j.batchId, filename: j.filename)
        }
        let data = (try? JSONEncoder().encode(pending)) ?? Data()
        UserDefaults.standard.set(data, forKey: Self.persistKey)
    }

    private func loadPersisted() {
        guard let data = UserDefaults.standard.data(forKey: Self.persistKey),
              let items = try? JSONDecoder().decode([Persisted].self, from: data) else { return }
        let resumed = items.map {
            Job(id: $0.ingestId, batchId: $0.batchId, filename: $0.filename,
                state: .processing, startedAt: Date())
        }
        for j in resumed where !jobs.contains(where: { $0.id == j.id }) {
            jobs.append(j)
        }
    }

    // MARK: - Image preparation (HEIC/PNG/etc → JPEG)

    static func prepareImage(url: URL) throws -> (Data, String, String) {
        let raw = try Data(contentsOf: url)
        guard let src = CGImageSourceCreateWithData(raw as CFData, nil) else {
            throw APIError.http(0, "Cannot read image")
        }
        let opts: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceThumbnailMaxPixelSize: 2048,
            kCGImageSourceCreateThumbnailWithTransform: true,
        ]
        guard let img = CGImageSourceCreateThumbnailAtIndex(src, 0, opts as CFDictionary) else {
            throw APIError.http(0, "Cannot decode image")
        }
        let out = NSMutableData()
        guard let dest = CGImageDestinationCreateWithData(
            out, UTType.jpeg.identifier as CFString, 1, nil
        ) else {
            throw APIError.http(0, "Cannot create JPEG encoder")
        }
        CGImageDestinationAddImage(dest, img, [
            kCGImageDestinationLossyCompressionQuality: 0.85
        ] as CFDictionary)
        guard CGImageDestinationFinalize(dest) else {
            throw APIError.http(0, "JPEG encode failed")
        }
        let base = url.deletingPathExtension().lastPathComponent
        return (out as Data, base + ".jpg", "image/jpeg")
    }
}
