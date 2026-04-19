//
//  GeneratedClientSmokeTest.swift
//
//  Compile-only smoke test for the swift-openapi-generator wiring.
//  Calling `smokeTestGeneratedClient()` from a debug menu confirms the
//  full chain works at runtime: SwiftPM packages resolve, the build-tool
//  plugin generates Client/Types from openapi.json, OpenAPIURLSession
//  transports it, and the Components.Schemas.* types decode the live
//  backend response.
//
//  The hand-written APIClient.swift is still the production path; this
//  file proves the generated client is ready for incremental migration.
//

#if DEBUG
import Foundation
import OpenAPIRuntime
import OpenAPIURLSession

@MainActor
func smokeTestGeneratedClient(baseURL: URL = URL(string: "http://localhost:3000")!) async {
    do {
        let client = Client(serverURL: baseURL, transport: URLSessionTransport())

        // 1. /health — simplest endpoint, just confirms the wire is up.
        let health = try await client.getHealth(.init())
        switch health {
        case .ok(let ok):
            let body = try ok.body.json
            print("[smoke] /health → service=\(body.service) version=\(body.version)")
        }

        // 2. /receipts — exercises Components.Schemas.Receipt decoding
        //    against real Postgres data. Catches snake_case / number-as-string
        //    / required-field mismatches early.
        let receipts = try await client.getReceipts(.init(query: .init(limit: 3)))
        switch receipts {
        case .ok(let ok):
            let list = try ok.body.json
            print("[smoke] /receipts → got \(list.count) receipts")
            for r in list {
                print("  - \(r.id) \(r.merchant) \(r.date) total=\(r.total)")
            }
        case .badRequest(let bad):
            let body = try bad.body.json
            print("[smoke] /receipts → 400 \(body.issues)")
        }
    } catch {
        print("[smoke] FAILED: \(error)")
    }
}
#endif
