# TestFlight release automation

The local release command uses Xcode for the archive and upload, and Apple's App Store Connect API for processing status, test notes and internal distribution. It targets PSK Reporter Counter, app 6816545854, bundle com.tallackn.PSKReporterCounter and the existing Baseline UX group.

## Credentials

Use a dedicated **Developer** team API key. Apple team keys apply across the account's apps. The release tool checks the exact app and internal group before making changes.

Keep the downloaded private key and credentials.json in:

```text
~/Library/Application Support/PSKReporterCounter/Release/
```

The directory should have permissions 700 and both files 600. The configuration contains issuerID, keyID and the absolute privateKeyPath. It contains no copy of the private key. Neither file belongs in the source repository or app bundle.

The small native transport uses Apple's CryptoKit to sign a token valid for ten minutes and URLSession for HTTPS requests. The key and token stay inside that process. Redirects are rejected. The Python release tool receives the API response, and does not receive or log the token. Xcode continues using its configured Apple account for signing and uploading.

## Release

1. Increment CURRENT_PROJECT_VERSION in Configuration/AppStore.xcconfig and the development build number in Resources/Info.plist. Set both marketing versions if the public version changes.
2. Add the test instructions under ReleaseNotes.
3. Publish the reviewed source, tests, documentation and licence notices to [tallackn/PSKReporterCounter](https://github.com/tallackn/PSKReporterCounter), using the GitHub connector for hosted operations. Preserve existing history. Fetch the published revision into the local checkout and verify that its files match. Do not include credentials, build artefacts, local settings or private acceptance records.
4. Run from the clean checkout at that published revision:

```sh
bash scripts/release-testflight.sh --notes-file ReleaseNotes/1.2.1-13.txt
```

The command verifies API access and the destination, refuses an existing build number, checks the published source, runs release-tool tests, core tests and popover checks, archives, verifies the archive, preserves a versioned archive and source hashes, uploads, waits for Apple processing, saves the English (U.K.) test notes and assigns the build to Baseline UX. The native anchor check briefly opens its own test pane, varies a temporary status item's width across 50 refreshes and checks that the pane meets the menu bar without added top clearance and remains still. An optional --interactive run checks left-click toggling, right-click placement, outside-click dismissal and Escape. It requires an interactive macOS desktop and closes its own window afterwards. The release tool reads the saved notes, group membership and internal testing state back before reporting success.

### Required GitHub publication for every build

Every new build uploaded to App Store Connect must have its exact source published first. This applies to internal TestFlight builds as well as public releases. Continue publishing through the GitHub connector when working with Codex. The local release command verifies publication using Git's public read access and does not need a GitHub write credential.

The check requires a clean Git checkout whose HEAD matches the repository's main branch. Uncommitted changes, untracked source files and unpublished commits stop the release. It checks again after archiving, then records the commit, tree, source URL, version, build number and app file hashes in PSKSourceRevision.json at the archive root. The file is outside the signed app bundle. The upload script independently checks that record against the source and archived app, including when invoked directly. A change during the build or after recording stops the upload.

The frozen archive and final TestFlight result retain the source revision, so later changes to main do not erase the build's source identity. Read the version's ReleaseNotes file at that immutable commit to identify its changes. Public source publication is authorised for each release; App Review and public app release remain separate actions.

Stage logs are written under build/Releases/VERSION-BUILD. The final result is saved as build/testflight-VERSION-BUILD-result.json. Source hashes and the frozen archive remain under build. Keep these release artefacts outside Git.

If processing or TestFlight setup is interrupted after a successful upload, repeat with `--resume`. This skips the tests, archive and upload and completes the remaining API operations. Existing identical notes and group membership are left in place. If uploading itself fails, inspect its log and App Store Connect status before retrying the existing archive with scripts/distribute-app.sh --upload.

```sh
python3 scripts/app_store_connect.py check
python3 scripts/app_store_connect.py status --version 1.2.1 --build 13
bash scripts/release-testflight.sh --resume --notes-file ReleaseNotes/1.2.1-13.txt
```

Install updates through the Mac's TestFlight app. Record Nathan's installed-build UX result in VERIFICATION.md. App Review and public release remain separate authorised actions. The automation has no review-submission or public-release command.

## Verification

```sh
python3 -m unittest discover -s Tests/ReleaseToolsTests -v
```

The release-tool tests exercise processing transitions, failure and timeout handling, rejection of the wrong app/platform or an external group, export-compliance stops, verified test-note updates, idempotent distribution, safe resume and credential permissions. Source publication tests use a temporary local Git remote and cover dirty or unpublished source, remote changes, changes during building, missing provenance and modified archives. Live API authentication and installed-build UX results are checked separately.

The workflow was exercised with build 1.2.1 (11) on 27 September 2026. It completed the archive and upload, then the resume path completed test-note verification and internal distribution after a beta-group query correction. Apple returned IN_BETA_TESTING, and TestFlight installed that build on this Mac.

API endpoints and request shapes were checked against Apple's current [OpenAPI specification](https://developer.apple.com/sample-code/app-store-connect/app-store-connect-openapi-specification.zip). Authentication follows [Apple's token documentation](https://developer.apple.com/documentation/appstoreconnectapi/generating-tokens-for-api-requests).
