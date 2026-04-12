import Foundation

enum APIError: LocalizedError {
    case badResponse(Int, String)
    case invalidURL
    case decoding(Error)
    case transport(Error)

    var errorDescription: String? {
        switch self {
        case .badResponse(let code, let msg): return "HTTP \(code): \(msg)"
        case .invalidURL: return "Invalid URL"
        case .decoding(let e): return "Decode error: \(e.localizedDescription)"
        case .transport(let e): return "Network error: \(e.localizedDescription)"
        }
    }
}

@MainActor
final class APIClient {
    private unowned let settings: AppSettings
    private let session: URLSession

    init(settings: AppSettings, session: URLSession = .shared) {
        self.settings = settings
        self.session = session
    }

    private func request(_ path: String, method: String = "GET", query: [String: String?] = [:]) throws -> URLRequest {
        var comps = URLComponents(url: settings.baseURL.appendingPathComponent(path), resolvingAgainstBaseURL: false)
        let items = query.compactMap { key, value -> URLQueryItem? in
            guard let v = value, !v.isEmpty else { return nil }
            return URLQueryItem(name: key, value: v)
        }
        if !items.isEmpty { comps?.queryItems = items }
        guard let url = comps?.url else { throw APIError.invalidURL }
        var req = URLRequest(url: url)
        req.httpMethod = method
        if let token = settings.bearerToken, !token.isEmpty {
            req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        return req
    }

    private func send<T: Decodable>(_ req: URLRequest, as: T.Type = T.self) async throws -> T {
        do {
            let (data, resp) = try await session.data(for: req)
            guard let http = resp as? HTTPURLResponse else {
                throw APIError.badResponse(0, "no response")
            }
            guard (200..<300).contains(http.statusCode) else {
                let msg = String(data: data, encoding: .utf8) ?? ""
                throw APIError.badResponse(http.statusCode, msg)
            }
            do {
                return try JSONDecoder().decode(T.self, from: data)
            } catch {
                throw APIError.decoding(error)
            }
        } catch let e as APIError {
            throw e
        } catch {
            throw APIError.transport(error)
        }
    }

    // MARK: - Endpoints

    func listReceipts(from: String? = nil, to: String? = nil, category: Category? = nil, limit: Int = 100) async throws -> [Receipt] {
        let req = try request("/receipts", query: [
            "from": from, "to": to,
            "category": category?.rawValue,
            "limit": String(limit)
        ])
        return try await send(req)
    }

    func getReceipt(_ id: String) async throws -> Receipt {
        let req = try request("/receipt/\(id)")
        return try await send(req)
    }

    func deleteReceipt(_ id: String) async throws {
        let req = try request("/receipt/\(id)", method: "DELETE")
        let (_, resp) = try await session.data(for: req)
        guard let http = resp as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw APIError.badResponse((resp as? HTTPURLResponse)?.statusCode ?? 0, "delete failed")
        }
    }

    func summary(from: String? = nil, to: String? = nil) async throws -> [SpendingSummary] {
        let req = try request("/summary", query: ["from": from, "to": to])
        return try await send(req)
    }

    func job(_ id: String) async throws -> JobStatus {
        let req = try request("/jobs/\(id)")
        return try await send(req)
    }

    func imageURL(for receiptId: String) -> URL {
        settings.baseURL.appendingPathComponent("/receipt/\(receiptId)/image")
    }

    var authToken: String? { settings.bearerToken }

    func uploadReceipt(imageData: Data, filename: String, mimeType: String = "image/jpeg", notes: String? = nil) async throws -> UploadResponse {
        var req = try request("/receipt", method: "POST")
        let boundary = "Boundary-\(UUID().uuidString)"
        req.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        var body = Data()
        func append(_ s: String) { body.append(s.data(using: .utf8)!) }
        append("--\(boundary)\r\n")
        append("Content-Disposition: form-data; name=\"image\"; filename=\"\(filename)\"\r\n")
        append("Content-Type: \(mimeType)\r\n\r\n")
        body.append(imageData)
        append("\r\n")
        if let notes, !notes.isEmpty {
            append("--\(boundary)\r\n")
            append("Content-Disposition: form-data; name=\"notes\"\r\n\r\n")
            append(notes)
            append("\r\n")
        }
        append("--\(boundary)--\r\n")
        req.httpBody = body

        do {
            let (data, resp) = try await session.upload(for: req, from: body)
            guard let http = resp as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
                let code = (resp as? HTTPURLResponse)?.statusCode ?? 0
                let msg = String(data: data, encoding: .utf8) ?? ""
                throw APIError.badResponse(code, msg)
            }
            return try JSONDecoder().decode(UploadResponse.self, from: data)
        } catch let e as APIError {
            throw e
        } catch {
            throw APIError.transport(error)
        }
    }
}
