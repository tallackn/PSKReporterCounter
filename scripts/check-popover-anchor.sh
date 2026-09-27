#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
PSK_CHECK_APP="$PWD/build/Popover Anchor Check.app"
PSK_CHECK_RESULT="$PWD/build/popover-anchor-check.json"
mkdir -p "$PSK_CHECK_APP/Contents/MacOS" .build/ModuleCache
xcrun swiftc -module-cache-path "$PWD/.build/ModuleCache" \
    -target arm64-apple-macosx13.0 \
    App/Counter/Support/GraphPopoverAnchor.swift \
    App/Counter/Support/GraphPopoverDismissal.swift \
    App/Counter/Support/GraphPopoverPlacement.swift \
    App/Counter/Support/StatusCountImage.swift \
    Tests/PSKReporterWindowTests/PopoverAnchorCheck.swift \
    -o "$PSK_CHECK_APP/Contents/PopoverAnchorCheck"
mv "$PSK_CHECK_APP/Contents/PopoverAnchorCheck" "$PSK_CHECK_APP/Contents/MacOS/PopoverAnchorCheck"
python3 - "$PSK_CHECK_APP" "$PSK_CHECK_RESULT" <<'PY'
import pathlib, plistlib, sys
app = pathlib.Path(sys.argv[1])
(app / 'Contents/Info.plist').write_bytes(plistlib.dumps({
    'CFBundleIdentifier': 'com.tallackn.PSKReporterCounter.AnchorCheck',
    'CFBundleName': 'Popover Anchor Check', 'CFBundleExecutable': 'PopoverAnchorCheck',
    'CFBundlePackageType': 'APPL', 'LSUIElement': True, 'LSMinimumSystemVersion': '13.0'}))
pathlib.Path(sys.argv[2]).unlink(missing_ok=True)
PY
codesign --force --sign - "$PSK_CHECK_APP"
open -n -W "$PSK_CHECK_APP" --args "$PSK_CHECK_RESULT" "$@"
python3 - "$PSK_CHECK_RESULT" <<'PY'
import json, pathlib, sys
result = json.loads(pathlib.Path(sys.argv[1]).read_text())
print(json.dumps(result, indent=2))
assert result['passed'], result['error']
PY
