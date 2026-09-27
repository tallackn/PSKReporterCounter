#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."

PSK_CHECK_CALLSIGN="${1:?Supply a transmitting callsign for the sandbox live check}"
PSK_CHECK_SECONDS="${2:-75}"
export CLANG_MODULE_CACHE_PATH="$PWD/.build/ModuleCache"
export SWIFT_MODULECACHE_PATH="$PWD/.build/ModuleCache"
mkdir -p "$CLANG_MODULE_CACHE_PATH" build
xcrun swift build --disable-sandbox --configuration release --arch arm64 \
    --scratch-path .build --cache-path .build/cache --config-path .build/config \
    --security-path .build/security --product PSKReporterProbe
PSK_CHECK_BIN="$(xcrun swift build --disable-sandbox --configuration release --arch arm64 \
    --scratch-path .build --cache-path .build/cache --config-path .build/config \
    --security-path .build/security --show-bin-path)"
PSK_CHECK_APP="$PWD/build/PSK Sandbox Check.app"
PSK_CHECK_BOUNDARY="$PWD/build/sandbox-boundary-fixture.txt"
mkdir -p "$PSK_CHECK_APP/Contents/MacOS" "$PSK_CHECK_APP/Contents/Resources"
cp "$PSK_CHECK_BIN/PSKReporterProbe" "$PSK_CHECK_APP/Contents/MacOS/PSKReporterProbe"
cp LICENSE "$PSK_CHECK_APP/Contents/Resources/LICENSE.txt"
cp Resources/PrivacyInfo.xcprivacy "$PSK_CHECK_APP/Contents/Resources/PrivacyInfo.xcprivacy"
for PSK_RESOURCE in "$PSK_CHECK_BIN"/*.bundle; do
    if [ -d "$PSK_RESOURCE" ]; then
        ditto "$PSK_RESOURCE" "$PSK_CHECK_APP/Contents/Resources/$(basename "$PSK_RESOURCE")"
    fi
done
cat > "$PSK_CHECK_APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
    <key>CFBundleIdentifier</key><string>com.tallackn.PSKReporterCounter.SandboxCheck</string>
    <key>CFBundleName</key><string>PSK Sandbox Check</string>
    <key>CFBundleExecutable</key><string>PSKReporterProbe</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>CFBundleShortVersionString</key><string>1.0</string>
    <key>CFBundleVersion</key><string>1</string>
    <key>LSMinimumSystemVersion</key><string>13.0</string>
    <key>LSBackgroundOnly</key><true/>
</dict></plist>
PLIST
bash scripts/sign-local-app.sh "$PSK_CHECK_APP"
printf 'Controlled sandbox boundary fixture.\n' > "$PSK_CHECK_BOUNDARY"
for PSK_PHASE in write read; do
    /usr/bin/open -n -g -W "$PSK_CHECK_APP" \
        --stdout "$PWD/build/sandbox-preferences-$PSK_PHASE.txt" \
        --stderr "$PWD/build/sandbox-preferences-$PSK_PHASE-errors.txt" \
        --args --sandbox-preferences "$PSK_PHASE" "$PSK_CHECK_BOUNDARY" "$PSK_CHECK_CALLSIGN"
    /usr/bin/grep -q "Sandbox preferences $PSK_PHASE passed" "build/sandbox-preferences-$PSK_PHASE.txt"
done
/usr/bin/open -n -g -W "$PSK_CHECK_APP" \
    --stdout "$PWD/build/sandbox-live-check.txt" --stderr "$PWD/build/sandbox-live-errors.txt" \
    --args "$PSK_CHECK_CALLSIGN" --monitor "$PSK_CHECK_SECONDS"
/usr/bin/grep -Eq 'Verified [0-9]+ live updates' build/sandbox-live-check.txt
printf 'Sandbox boundary, bundled resources, settings persistence and live monitoring checks passed.\n'
