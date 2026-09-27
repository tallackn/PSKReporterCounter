#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
PSK_DESTINATION=export
if [ "${1:-}" = "--upload" ]; then
    PSK_DESTINATION=upload
    python3 scripts/release_source.py verify --archive "$PWD/build/PSKReporterCounter.xcarchive"
elif [ "$#" -ne 0 ]; then
    printf 'Usage: bash scripts/distribute-app.sh [--upload]\n' >&2
    exit 2
fi
mkdir -p build/AppStoreExport
python3 - "$PSK_DESTINATION" <<'PY'
import pathlib, plistlib, sys
options = plistlib.loads(pathlib.Path('Configuration/ExportOptions.plist').read_bytes())
options['destination'] = sys.argv[1]
pathlib.Path('build/AppStoreExport/ExportOptions.plist').write_bytes(plistlib.dumps(options))
PY
bash scripts/verify-archive.sh "$PWD/build/PSKReporterCounter.xcarchive"
# Upload authorisation is explicit. This uploads to App Store Connect, but does
# not submit to App Review or release the app publicly.
xcodebuild -exportArchive -archivePath "$PWD/build/PSKReporterCounter.xcarchive" \
    -exportOptionsPlist "$PWD/build/AppStoreExport/ExportOptions.plist" \
    -exportPath "$PWD/build/AppStoreExport" -allowProvisioningUpdates
