#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p build
# Archive only. The installed TestFlight copy is the UX baseline.
xcodebuild -project PSKReporterCounter.xcodeproj -scheme PSKReporterCounter \
    -configuration Release -destination 'generic/platform=macOS' \
    -derivedDataPath "$PWD/build/XcodeDerivedData" \
    -clonedSourcePackagesDirPath "$PWD/build/SourcePackages" \
    -archivePath "$PWD/build/PSKReporterCounter.xcarchive" \
    -allowProvisioningUpdates archive ARCHS=arm64 "$@"
bash scripts/verify-archive.sh "$PWD/build/PSKReporterCounter.xcarchive"
