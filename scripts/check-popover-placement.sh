#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p build .build/ModuleCache
xcrun swiftc -module-cache-path "$PWD/.build/ModuleCache" \
    -target arm64-apple-macosx13.0 \
    App/Counter/Support/GraphPopoverPlacement.swift \
    Tests/PSKReporterWindowTests/PopoverPlacementCheck.swift \
    -o build/CheckPopoverPlacement
build/CheckPopoverPlacement
