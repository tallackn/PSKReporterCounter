# Maintenance guide

Read this guide, the [README](README.md), applicable checkout instructions and the [accepted 2.0 baseline](ReleaseNotes/2.0-baseline.md) before changing the project. The README covers local build, installation and operation. [Release automation](RELEASE_AUTOMATION.md) describes the existing TestFlight tooling.

## Work and authority

- The original project chat, **PSK Reporter Counter: Planning and releases**, handles backlog, priorities and release decisions. Give each distinct feature or bug its own chat and keep related implementation and testing together.
- GitHub Issues is the durable backlog. Distinguish **current todo** from **future features** explicitly in issue labels or descriptions. Recording an idea does not authorise implementation. Confirm the authorised scope before starting it.
- Use a separate branch and reviewable pull request per change, with `codex/` branches for Codex work. Initially keep one implementation task active at a time. Prefer the GitHub connector for hosted operations. Review the current source and instructions rather than relying on an earlier chat.
- Preserve `sources/` as read-only synced references. Local `AGENTS.md`, `VERIFICATION.md`, `TESTFLIGHT_CHECKLIST.md`, `APP_STORE_PLAN.md` and build evidence are excluded from Git. Keep credentials, signing material, reviewer contacts and private acceptance evidence outside the public repository. Do not edit global memory files.
- Warn Nathan before visible desktop actions, including native diagnostics, or replacing a running app. Preserve the installed public copy unless replacement is explicitly authorised. A documentation task does not authorise a build upload, submission, release or feature implementation.

## Accepted behaviour

The counter and both graphs share one immutable sliding-window snapshot, refreshed once per second. This is not the obsolete fixed-interval design. Defaults are 15 minutes, All bands, All modes and **Count unique stations** on.

The app subscribes once to `pskr/filter/v2/{band}/{mode}/{sending-callsign}/#` through `mqtt.pskreporter.info:1884` with TLS and system certificate verification. The broker filters the transmitting callsign, band and mode. JSON fields are also checked locally. There is no global subscription, database polling or historical download.

Membership uses arrival time at the app, in `(now - window, now]`, rather than the report's reception timestamp. Callsigns are trimmed and uppercased. Unique counting selects the earliest eligible report per receiving callsign, across bands and modes when All is selected. Its arrival time and SNR represent the station. When it expires, the next eligible report takes over. With unique counting off, every eligible report counts. The one-second histogram total equals the counter.

SNR comes from `rp`, accepting finite numeric values or numeric strings. Missing or invalid SNR does not remove a report from the count. Only selected reports with valid SNR enter the signal summary, so a unique station's later SNR does not replace an earliest report with missing SNR. Quartiles use linear interpolation (R type 7), with whiskers at observed values within 1.5 IQR and remaining values shown as outliers. Fading expired points are visual only and excluded from statistics.

Changing callsign, band or mode clears collection and reconnects. Changing only the window or counting setting recalculates retained history without reconnecting. Increasing the window cannot recover expired history. A saved valid callsign starts monitoring on launch, while Stop Monitoring pauses only the session. Interruptions reset collection and retain a warning until a full uninterrupted window has accumulated. Retry delay starts at 5 seconds and doubles to 5 minutes.

Left-click toggles the graphs. Right-click or Control-click opens the menu. Outside-click and Escape dismiss the graphs. Each opening keeps a fixed screen anchor despite status item width changes. Settings can close without stopping monitoring. Login-item state is read from macOS.

## Source map and threading

| Path | Responsibility |
| --- | --- |
| `App/Core/Models` | Filtering, decoding, arrival-window selection, histogram and SNR statistics |
| `App/Core/Services` | MQTT transport and buffered reception pipeline |
| `App/Core/Stores/MonitorModel.swift` | Shared main-actor state, one-second timer, settings, recovery and snapshot publication |
| `App/Counter/App`, `Platform` | Application lifecycle and small AppKit controllers |
| `App/Counter/Views`, `Support`, `Models` | SwiftUI settings and graphs, placement helpers, Help and About |
| `App/Probe`, `Tests` | Diagnostics, deterministic core tests, release-tool tests and native window checks |
| `Resources`, `Configuration`, `ThirdPartyLicences` | Bundle metadata, signing configuration, privacy and licence resources |
| `scripts`, `script/build_and_run.sh` | Tests, local build/run, archive verification and TestFlight automation |

A dedicated MQTT callback queue decodes and filters normal reports without dispatching them to the main thread. A short lock protects the inbox. A serial utility queue owns history and computes statistics after releasing the lock. The main actor receives finished snapshots. Overlapping calculations are skipped, and obsolete connection/configuration results are ignored. Buffers are bounded, with overflow reported visibly and a reconnect rather than an incomplete count. Preserve these semantics when changing the pipeline.

## Verification proportional to the change

For documentation alone, check source consistency, links, version references, whitespace and the public diff for private information. Do not imply that previous release checks were rerun.

For app changes on an Apple silicon Mac, run `./scripts/test.sh`. Run `./scripts/test.sh --sanitize thread` for relevant concurrency changes. Check presentation changes with `./scripts/check-popover-placement.sh` and `./scripts/check-popover-anchor.sh`. The latter opens a separate native diagnostic pane. Its optional `--interactive` mode covers click toggling, menu placement, outside-click and Escape. These require macOS, and the anchor check requires an interactive desktop.

Use README diagnostics for relevant feed or sandbox changes, noting that no reports can be a valid result. Build without launching with `./scripts/build-app.sh` when appropriate. `./script/build_and_run.sh --verify` closes the previous process and launches a replacement, so warn Nathan first and establish authority to replace it. Native UX, login items and installed distribution checks are separate from deterministic tests. Record environment, exact revision/build, commands, results and limitations. Avoid tests that merely restate a documentation edit.

## Versions and release procedure

1. Agree release scope and authorisation in the planning/release chat. Set `MARKETING_VERSION` and `CURRENT_PROJECT_VERSION` in `Configuration/AppStore.xcconfig`, and matching `CFBundleShortVersionString` and `CFBundleVersion` in `Resources/Info.plist`. Use a new, unused build number for an upload. Documentation-only commits do not increment app versions or builds.
2. Add build-specific TestFlight notes in `ReleaseNotes/VERSION-BUILD.txt`. Complete appropriate automated and native checks, review the PR and publish the reviewed source. The release tool requires a clean checkout with HEAD equal to published `main` and verifies it again after archiving.
3. Only with upload authority, run the TestFlight procedure in [RELEASE_AUTOMATION.md](RELEASE_AUTOMATION.md) using the new build's notes. It tests, archives, verifies licences/signature/entitlements, records provenance, uploads and verifies processing and internal distribution. It does not submit to App Review or publish publicly. Warn Nathan before its native desktop check.
4. Retain the frozen archive, `PSKSourceRevision.json`, hashes, logs and final TestFlight result privately. Verify the recorded commit, tree, bundle identifier, version/build and archived app against the exact upload. Do not infer uploaded source identity from the current branch tip or version strings alone.
5. Install through TestFlight and obtain Nathan's UX acceptance for that exact build. Then seek the separate authorised App Store submission/release decision. Preserve private review details outside Git. Record Apple approval and public-installation acceptance separately, including launch at login when checked.
6. Align public source, version tags and release notes with the recorded uploaded commit. Use a version/build tag such as `v2.0-build15` only after verifying provenance and obtaining the release decision. Never move a release tag to later documentation commits or silently retag a different build. Tag/release creation is a separate hosted operation, not implied by writing a baseline record.

The accepted public baseline remains 2.0 (15). Do not rerun its upload as part of housekeeping. Follow the automation's inspection and resume procedure for an interrupted authorised release rather than creating a duplicate upload.
