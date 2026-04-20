//
//  APIClient.swift
//
//  Thin facade over the swift-openapi-generator output (`Client`). Each
//  method here unwraps the generated Operation Output enum into either a
//  typed value or an APIError. Domain code (UploadService, ReceiptStore,
//  views) talks to this facade — never to the generated Client directly —
//  so the spec-driven method renames are absorbed in one place.
//

import Foundation
import HTTPTypes
import OpenAPIRuntime
import OpenAPIURLSession

enum APIError: LocalizedError {
    case http(Int, String)
    case decoding(String)
    case transport(Error)
    case undocumented(Int)

    var errorDescription: String? {
        switch self {
        case .http(let code, let msg): return "HTTP \(code): \(msg)"
        case .decoding(let m): return "Decode error: \(m)"
        case .transport(let e): return "Network error: \(e.localizedDescription)"
        case .undocumented(let c): return "Undocumented status \(c)"
        }
    }
}

@MainActor
final class APIClient {
    private unowned let settings: AppSettings
    private let client: Client

    init(settings: AppSettings) {
        self.settings = settings
        // Snapshot token at init. Token rarely changes (Settings UI); to
        // pick up a new token, restart the app. This avoids capturing the
        // @MainActor AppSettings inside a Sendable middleware closure.
        let tokenSnapshot = settings.bearerToken
        let middlewares: [any ClientMiddleware] = [BearerTokenMiddleware(token: tokenSnapshot)]
        self.client = Client(
            serverURL: settings.baseURL,
            transport: URLSessionTransport(),
            middlewares: middlewares
        )
    }

    // MARK: - Transactions

    func listTransactions(limit: Int? = nil) async throws -> [Transaction] {
        let out = try await client.getV1Transactions(.init(query: .init(limit: limit)))
        switch out {
        case .ok(let ok):
            switch ok.body {
            case .json(let payload): return payload.items
            }
        case .undocumented(let s, _):
            throw APIError.undocumented(s)
        }
    }

    func getTransaction(_ id: String) async throws -> Transaction {
        let out = try await client.getV1TransactionsId(.init(path: .init(id: id)))
        switch out {
        case .ok(let ok):
            switch ok.body {
            case .json(let txn): return txn
            }
        case .notModified:
            throw APIError.http(304, "Not modified")
        case .notFound:
            throw APIError.http(404, "Not found")
        case .undocumented(let s, _):
            throw APIError.undocumented(s)
        }
    }

    // NOTE: deleteTransaction / voidTransaction are deferred to a follow-up
    // PR — both endpoints require an If-Match header carrying the
    // transaction's ETag (optimistic concurrency). Surfacing version
    // through the facade cleanly is its own design problem.

    // MARK: - Reports

    func summary(groupBy: Operations.GetV1ReportsSummary.Input.Query.GroupByPayload = .category)
        async throws -> SummaryReport
    {
        let out = try await client.getV1ReportsSummary(.init(query: .init(groupBy: groupBy)))
        switch out {
        case .ok(let ok):
            switch ok.body {
            case .json(let report): return report
            }
        case .notFound:
            throw APIError.http(404, "Report endpoint not found")
        case .undocumented(let s, _):
            throw APIError.undocumented(s)
        }
    }

    // MARK: - Ingest pipeline

    /// Upload a single file as a one-item batch. Returns the batchId +
    /// the singleton ingestId so callers can poll progress.
    func uploadOne(imageData: Data, filename: String, mimeType: String = "image/jpeg")
        async throws -> CreateBatchResponse
    {
        let filePart = OpenAPIRuntime.MultipartPart(
            payload: Components.Schemas.CreateBatchForm.FilesPayload(
                body: HTTPBody(imageData)
            ),
            filename: filename
        )
        let multipartBody: MultipartBody<Components.Schemas.CreateBatchForm> =
            .init([.files(filePart)])
        let body: Operations.PostV1IngestBatch.Input.Body = .multipartForm(multipartBody)

        let out = try await client.postV1IngestBatch(.init(body: body))
        switch out {
        case .accepted(let acc):
            switch acc.body {
            case .json(let payload): return payload
            }
        case .unprocessableContent(let p):
            switch p.body {
            case .applicationProblemJson(let problem):
                throw APIError.http(422, problem.title)
            }
        case .undocumented(let s, _):
            throw APIError.undocumented(s)
        }
    }

    func getIngest(_ id: String) async throws -> Ingest {
        let out = try await client.getV1IngestsId(.init(path: .init(id: id)))
        switch out {
        case .ok(let ok):
            switch ok.body {
            case .json(let ingest): return ingest
            }
        case .notFound:
            throw APIError.http(404, "Not found")
        case .undocumented(let s, _):
            throw APIError.undocumented(s)
        }
    }

    // MARK: - Documents

    /// Direct URL to fetch a document's binary content. Used for inline
    /// image rendering — bypasses the generated client because we want the
    /// raw URL for AsyncImage / NSImage(contentsOf:).
    func documentContentURL(_ documentId: String) -> URL {
        settings.baseURL
            .appendingPathComponent("v1")
            .appendingPathComponent("documents")
            .appendingPathComponent(documentId)
            .appendingPathComponent("content")
    }

    var authToken: String? { settings.bearerToken }
}

// MARK: - Bearer token middleware

private struct BearerTokenMiddleware: ClientMiddleware {
    let token: String?

    func intercept(
        _ request: HTTPRequest,
        body: HTTPBody?,
        baseURL: URL,
        operationID: String,
        next: @Sendable (HTTPRequest, HTTPBody?, URL) async throws -> (HTTPResponse, HTTPBody?)
    ) async throws -> (HTTPResponse, HTTPBody?) {
        var req = request
        if let token, !token.isEmpty {
            req.headerFields[.authorization] = "Bearer \(token)"
        }
        return try await next(req, body, baseURL)
    }
}
