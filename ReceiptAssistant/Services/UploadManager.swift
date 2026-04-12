import Foundation
import AppKit
import ImageIO
import UniformTypeIdentifiers

@MainActor
final class UploadManager: ObservableObject {
    enum State: Equatable {
        case idle
        case uploading
        case queued
        case done(Receipt)
        case failed(String)
    }

    @Published var state: State = .idle

    private let client: APIClient
    private let store: ReceiptStore

    init(client: APIClient, store: ReceiptStore) {
        self.client = client
        self.store = store
    }

    func upload(fileURL: URL, notes: String? = nil) async {
        state = .uploading
        do {
            let (data, filename, mime) = try Self.prepare(url: fileURL)
            let resp = try await client.uploadReceipt(imageData: data, filename: filename, mimeType: mime, notes: notes)
            state = .queued
            try await poll(jobId: resp.jobId, receiptId: resp.receiptId)
        } catch {
            state = .failed((error as? LocalizedError)?.errorDescription ?? "\(error)")
        }
    }

    private func poll(jobId: String, receiptId: String) async throws {
        while true {
            try await Task.sleep(nanoseconds: 2_000_000_000)
            let job = try await client.job(jobId)
            switch job.status {
            case "queued":
                state = .queued
            case "done":
                let r = try await client.getReceipt(receiptId)
                state = .done(r)
                await store.refreshAll()
                return
            case "error":
                state = .failed(job.error ?? "Processing failed")
                return
            default:
                break
            }
        }
    }

    static func prepare(url: URL) throws -> (Data, String, String) {
        let ext = url.pathExtension.lowercased()
        if ext == "heic" || ext == "heif" {
            let data = try Data(contentsOf: url)
            guard let jpeg = heicToJPEG(data) else {
                throw APIError.badResponse(0, "HEIC conversion failed")
            }
            return (jpeg, url.deletingPathExtension().lastPathComponent + ".jpg", "image/jpeg")
        }
        let data = try Data(contentsOf: url)
        let mime = ext == "png" ? "image/png" : "image/jpeg"
        return (data, url.lastPathComponent, mime)
    }

    private static func heicToJPEG(_ data: Data) -> Data? {
        guard let src = CGImageSourceCreateWithData(data as CFData, nil),
              let img = CGImageSourceCreateImageAtIndex(src, 0, nil) else { return nil }
        let out = NSMutableData()
        guard let dest = CGImageDestinationCreateWithData(out, UTType.jpeg.identifier as CFString, 1, nil) else { return nil }
        let options: [CFString: Any] = [kCGImageDestinationLossyCompressionQuality: 0.9]
        CGImageDestinationAddImage(dest, img, options as CFDictionary)
        guard CGImageDestinationFinalize(dest) else { return nil }
        return out as Data
    }
}
