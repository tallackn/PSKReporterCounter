#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
PSK_ARCHIVE="${1:?Supply the archive path}"
PSK_APP="$PSK_ARCHIVE/Products/Applications/PSK Reporter Counter.app"
test -f "$PSK_ARCHIVE/dSYMs/PSK Reporter Counter.app.dSYM/Contents/Resources/DWARF/PSKReporterCounter"
codesign --verify --deep --strict --verbose=2 "$PSK_APP"
codesign --display --entitlements - --xml "$PSK_APP" > build/archive-entitlements.plist
plutil -lint "$PSK_APP/Contents/Info.plist" "$PSK_APP/Contents/Resources/PrivacyInfo.xcprivacy"
xcrun swift scripts/VerifyLegalResources.swift "$PSK_APP"
python3 - "$PSK_APP" <<'PY'
import pathlib, plistlib, subprocess, sys
app = pathlib.Path(sys.argv[1])
info = plistlib.loads((app / 'Contents/Info.plist').read_bytes())
entitlements = plistlib.loads(pathlib.Path('build/archive-entitlements.plist').read_bytes())
assert info['CFBundleIdentifier'] == 'com.tallackn.PSKReporterCounter'
assert info['PSKSourceRepositoryURL'] == 'https://github.com/tallackn/PSKReporterCounter'
assert info['LSMinimumSystemVersion'] == '13.0'
assert info['ITSAppUsesNonExemptEncryption'] is False
assert entitlements['com.apple.security.app-sandbox'] is True
assert entitlements['com.apple.security.network.client'] is True
assert entitlements.get('com.apple.security.network.server', False) is False
binary = app / 'Contents/MacOS/PSKReporterCounter'
assert subprocess.check_output(['lipo', '-archs', str(binary)], text=True).strip() == 'arm64'
assert list((app / 'Contents/Resources').glob('**/CocoaMQTT_CocoaMQTT.bundle/**/PrivacyInfo.xcprivacy'))
assert not list(app.glob('**/*Probe*'))
assert not list(app.glob('**/*SandboxCheck*'))
print(f"Verified archive {info['CFBundleShortVersionString']} ({info['CFBundleVersion']}): arm64, sandbox, licences, privacy and symbols.")
PY
