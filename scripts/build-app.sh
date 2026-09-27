#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."

export CLANG_MODULE_CACHE_PATH="$PWD/.build/ModuleCache"
export SWIFT_MODULECACHE_PATH="$PWD/.build/ModuleCache"
mkdir -p "$CLANG_MODULE_CACHE_PATH" build

xcrun swift build --disable-sandbox --configuration release --arch arm64 \
    --scratch-path .build --cache-path .build/cache --config-path .build/config \
    --security-path .build/security --product PSKReporterCounter

PSK_BIN_DIR="$(xcrun swift build --disable-sandbox --configuration release --arch arm64 \
    --scratch-path .build --cache-path .build/cache --config-path .build/config \
    --security-path .build/security --show-bin-path)"
PSK_APP="$PWD/build/PSK Reporter Counter.app"
mkdir -p "$PSK_APP/Contents/MacOS" "$PSK_APP/Contents/Resources"
cp "$PSK_BIN_DIR/PSKReporterCounter" "$PSK_APP/Contents/MacOS/PSKReporterCounter.new"
mv -f "$PSK_APP/Contents/MacOS/PSKReporterCounter.new" "$PSK_APP/Contents/MacOS/PSKReporterCounter"
cp Resources/Info.plist "$PSK_APP/Contents/Info.plist"
for PSK_RESOURCE in "$PSK_BIN_DIR"/*.bundle; do
    if [ -d "$PSK_RESOURCE" ]; then
        ditto "$PSK_RESOURCE" "$PSK_APP/Contents/Resources/$(basename "$PSK_RESOURCE")"
    fi
done
ditto ThirdPartyLicences "$PSK_APP/Contents/Resources/ThirdPartyLicences"
cp LICENSE "$PSK_APP/Contents/Resources/LICENSE.txt"
cp Resources/Acknowledgements.json "$PSK_APP/Contents/Resources/Acknowledgements.json"
cp Resources/PrivacyInfo.xcprivacy "$PSK_APP/Contents/Resources/PrivacyInfo.xcprivacy"
xcrun swift scripts/VerifyLegalResources.swift "$PSK_APP"
if [ ! -f "$PSK_APP/Contents/Resources/AppIcon.icns" ] || [ scripts/GenerateIcon.swift -nt "$PSK_APP/Contents/Resources/AppIcon.icns" ]; then
    xcrun swift scripts/GenerateIcon.swift "$PWD/build/AppIcon.iconset"
    xcrun iconutil --convert icns build/AppIcon.iconset --output "$PSK_APP/Contents/Resources/AppIcon.icns"
fi
plutil -lint "$PSK_APP/Contents/Info.plist"
plutil -lint "$PSK_APP/Contents/Resources/PrivacyInfo.xcprivacy" Resources/PSKReporterCounter.entitlements
bash scripts/sign-local-app.sh "$PSK_APP"
lipo -archs "$PSK_APP/Contents/MacOS/PSKReporterCounter"
ditto -c -k --keepParent "$PSK_APP" "$PWD/build/PSKReporterCounter-arm64.zip"
printf 'Built %s\n' "$PSK_APP"
