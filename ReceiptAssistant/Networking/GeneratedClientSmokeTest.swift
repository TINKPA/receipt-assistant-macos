//
//  GeneratedClientSmokeTest.swift
//
//  Runtime smoke test for the swift-openapi-generator wiring. Confirms
//  that SwiftPM packages resolve, the build-tool plugin generates
//  Client/Types from openapi.json, OpenAPIURLSession transports work,
//  and Components.Schemas.* types decode live backend responses.
//
//  How to run from CLI:
//      RUN_SMOKE_TEST=1 \
//        ~/Library/Developer/Xcode/DerivedData/ReceiptAssistant-*/Build/Products/Debug/ReceiptAssistant.app/Contents/MacOS/ReceiptAssistant
//  The app's .task hook in ReceiptAssistantApp checks this env var and
//  exits after running the smoke test (no UI shown).
//
//  The hand-written APIClient.swift is still the production path; this
//  file proves the generated client is ready for incremental migration.
//

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
        case .undocumented(let status, _):
            print("[smoke] /health → undocumented status \(status)")
        }

        // 2. /v1/transactions — exercises Components.Schemas.Transaction
        //    decoding against real Postgres data. Catches snake_case /
        //    decimal / required-field mismatches early.
        let txs = try await client.getV1Transactions(.init(query: .init(limit: 3)))
        switch txs {
        case .ok(let ok):
            switch ok.body {
            case .json(let payload):
                print("[smoke] /v1/transactions → got \(payload.items.count) txns")
                for t in payload.items {
                    print("  - \(t.id) payee=\(t.payee ?? "?") on=\(t.occurredOn) status=\(t.status.rawValue) postings=\(t.postings.count)")
                }
            }
        case .undocumented(let status, _):
            print("[smoke] /v1/transactions → undocumented status \(status)")
        }
    } catch {
        print("[smoke] FAILED: \(error)")
    }
}
