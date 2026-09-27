#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."

PSK_APP_TO_SIGN="${1:?Supply the local app bundle path}"
# Prefer this project's existing local identity so sandbox ownership remains
# stable across rebuilds. App Store archives will use Xcode distribution signing.
PSK_LOCAL_IDENTITY="${PSK_SIGNING_IDENTITY:-}"
if [ -z "$PSK_LOCAL_IDENTITY" ]; then
    PSK_LOCAL_IDENTITY="$(/usr/bin/security find-identity -v -p codesigning | \
        /usr/bin/awk '/"(Apple Development|Developer ID Application): .*\(33LJMNUTSN\)"/ { print $2; exit }')"
fi
PSK_LOCAL_IDENTITY="${PSK_LOCAL_IDENTITY:--}"
/usr/bin/codesign --force --sign "$PSK_LOCAL_IDENTITY" \
    --entitlements Resources/PSKReporterCounter.entitlements "$PSK_APP_TO_SIGN"
/usr/bin/codesign --verify --strict "$PSK_APP_TO_SIGN"
/usr/bin/codesign --display --entitlements - --xml "$PSK_APP_TO_SIGN" > build/verified-entitlements.plist
/usr/libexec/PlistBuddy -c 'Print :com.apple.security.app-sandbox' build/verified-entitlements.plist | /usr/bin/grep -qx true
/usr/libexec/PlistBuddy -c 'Print :com.apple.security.network.client' build/verified-entitlements.plist | /usr/bin/grep -qx true
printf 'Verified App Sandbox and outgoing network entitlements.\n'
