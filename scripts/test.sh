#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
export CLANG_MODULE_CACHE_PATH="$PWD/.build/ModuleCache"
export SWIFT_MODULECACHE_PATH="$PWD/.build/ModuleCache"
mkdir -p "$CLANG_MODULE_CACHE_PATH" build
xcrun swift test --disable-sandbox --arch arm64 --scratch-path .build \
    --cache-path .build/cache --config-path .build/config --security-path .build/security "$@"
