# Receipt Assistant — macOS

Native SwiftUI macOS client for the [Receipt Assistant](https://github.com/TINKPA/receipt-assistant) backend.

Feature parity with the [web frontend](https://github.com/TINKPA/receipt-assistant-frontend):
dashboard, transactions, monthly/yearly review, drag-drop upload with HEIC support.

## Requirements

- macOS 14+
- Xcode 15+
- [`xcodegen`](https://github.com/yonaskolb/XcodeGen) (`brew install xcodegen`) — the `.xcodeproj` is generated from `project.yml`, not committed
- Backend running at `http://localhost:3000`

## Build

```bash
xcodegen generate          # produces ReceiptAssistant.xcodeproj from project.yml
open ReceiptAssistant.xcodeproj
```

Or from CLI: `xcodebuild -scheme ReceiptAssistant build`.

## API client (typed, generated from OpenAPI)

The macOS app talks to the backend via two parallel paths:

- **Hand-written**: `Networking/APIClient.swift` (`URLSession` + custom `Codable` models in `Models/`). Currently the production path used by all views.
- **Generated**: Apple's [`swift-openapi-generator`](https://github.com/apple/swift-openapi-generator) build-tool plugin reads `Networking/Generated/openapi.json` (a copy of the backend's spec) and produces `Client.swift` + `Types.swift` at build time. The smoke test in `Networking/GeneratedClientSmokeTest.swift` shows how to use it.

Goal: incrementally migrate `APIClient.swift` callsites onto the generated client so the macOS app picks up backend API changes via codegen instead of hand-edited Swift.

### Refreshing the spec after a backend change

```bash
./scripts/refresh-openapi.sh   # pulls latest openapi.json from main on GitHub
xcodegen generate              # only needed if project.yml changed
xcodebuild -scheme ReceiptAssistant build
```

The build-tool plugin re-runs the generator whenever `openapi.json` or `openapi-generator-config.yaml` changes.

## Status

Scaffolding in progress. Generated API client wiring is in place; full migration of `APIClient.swift` to the generated client is a follow-up.
