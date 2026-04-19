#!/usr/bin/env bash
# Refresh the OpenAPI spec from the backend's main branch on GitHub.
# Run after the backend ships an API change and before regenerating the
# Xcode project. The build-tool plugin will pick up the new spec on the
# next `xcodebuild build` (or "Run" in Xcode) and regenerate Client.swift
# and Types.swift accordingly.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DEST="$ROOT/ReceiptAssistant/Networking/Generated/openapi.json"
URL="https://raw.githubusercontent.com/TINKPA/receipt-assistant/main/openapi/openapi.json"

echo "→ Fetching $URL"
curl -fsSL "$URL" -o "$DEST"
echo "✓ Wrote $DEST ($(wc -c <"$DEST") bytes)"

echo "Next: xcodegen generate && xcodebuild -scheme ReceiptAssistant build"
