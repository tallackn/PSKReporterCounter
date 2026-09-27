# PSK Reporter Counter

A native macOS menu bar app written in Swift, using AppKit, SwiftUI, Swift Charts and CocoaMQTT. Version 1.2.1 targets Apple silicon and macOS 13 or later.

## Run

For release acceptance, install and open **PSK Reporter Counter through TestFlight**. Quit any development copy first. Enter the **transmitting callsign**, choose the window length, band and mode, then select **Save and Start** or **Apply**. Existing settings should be retained under the same bundle identifier.

- **Left-click** the menu bar count for live graphs. They continue updating while the dropdown is open.
- **Right-click**, or Control-click, for Settings, Start/Stop Monitoring, Reconnect, About, Help and Quit.
- Closing Settings leaves monitoring running. Hide Dock icon takes effect immediately.
- A saved valid callsign starts listening automatically on every launch. **Stop Monitoring** pauses the current session only.
- Move the app to **Applications** before enabling **Launch automatically at login**. macOS may require approval in **System Settings > General > Login Items**. The app reads the actual system login item state.

## About and Help

**About PSK Reporter Counter** shows the version, author **Nathan Tallack (ZL2NU)**, data service credits and an offline licence reader. Choose **Licences**, then a component to read its full notices. About is available from the right-click menu and the app's main menu.

**Help** opens a searchable guide covering setup, menu bar controls, sliding windows, counting modes, graph interpretation, startup options, troubleshooting and privacy. It works offline. Open it from the right-click menu, the main Help menu or Command-question mark while the app is active. The guide includes an Open Settings button.

The original app source and documentation are released under the [MIT License](LICENSE). Third-party components retain their own terms. The complete inventory and provenance are in [ThirdPartyLicences/README.md](ThirdPartyLicences/README.md). **Source code on GitHub** in About opens [tallackn/PSKReporterCounter](https://github.com/tallackn/PSKReporterCounter).

## Sandbox and App Store preparation

The app now runs with App Sandbox enabled. Its entitlements allow outgoing network connections to receive the live feed. Preferences use the app container, and no user document access is requested. The app's privacy manifest declares UserDefaults access for its own preferences; CocoaMQTT retains its separate bundled manifest.

The app is currently tested through internal TestFlight. The planned public release is free and manually released after App Review and acceptance testing.

Builds, tests and release archives run locally. PSKReporterCounter.xcodeproj contains the native application target and shared archive scheme. The app uses the same sources and core as the Swift package. Release archives enable App Sandbox and Hardened Runtime, preserve licence resources and include the icon asset catalogue and privacy manifests.

~~~sh
bash scripts/test.sh
bash scripts/check-popover-placement.sh
bash scripts/check-popover-anchor.sh       # Brief native window regression check
bash scripts/archive-app.sh
bash scripts/distribute-app.sh            # Export for inspection
bash scripts/release-testflight.sh --notes-file ReleaseNotes/1.2.1-12.txt
~~~

The upload command uses Xcode's configured Apple account. It does not submit to App Review or release publicly. Configuration/AppStore.xcconfig controls the store version and build number. Increment the build number for each new upload. The installed TestFlight build, identified in About, is the UX baseline. The original local build-and-run script remains available for explicitly requested development work.

The [TestFlight release automation](RELEASE_AUTOMATION.md) combines verification, archiving, uploading, Apple processing, test notes and assignment to Baseline UX in one command. Before every upload, the exact source must be published to this GitHub repository. The release tool checks the published revision before and after building, records it with the archive, and blocks an upload if the source or archived app changes. It uses a dedicated Apple API key stored outside the project. The Mac's TestFlight app still handles installation, followed by the installed-build UX check.

## Sliding window

The menu bar counter and both graphs use the same snapshot, refreshed **once per second**. The default window is **15 minutes**. Other choices are **1, 5, 10, 30, 60 and 120 minutes**. Band and mode default to **All**. Saved window preferences are retained.

**Count unique stations** is enabled by default. With it enabled, the count is the number of distinct receiving callsigns whose reports arrived within the selected window. Repeated reports from one station count once, including across bands and modes when All is selected. With it disabled, every report counts, including repeated reports from the same station. The setting applies to the counter and both graphs. Changing it and selecting Apply recalculates the retained window without reconnecting or clearing reports.

The boundary is (now minus window, now], excluding the oldest boundary and including the current time. When unique counting is enabled, the **first report from each station still inside the window** supplies its arrival time and signal measurement. When that report expires, the station's next report inside the window becomes its representative. A station disappears when none of its reports remains in the window.

Reports are counted by **arrival at this app**, independently of their reception timestamps. Reports may describe transmissions made several minutes earlier because reporting is batched upstream. A zero means no qualifying reports have arrived within the window. PSK Reporter's map may show a different count because it uses reception times and a different history.

### Graphs

- **Arrivals:** one-second histogram bins, using the current counting setting. The sum of the bins equals the menu bar count. Now is at the right and history moves left once per second. Longer windows retain one-second bins. **Detail** expands the chart so individual seconds can be inspected by scrolling horizontally. Hover to read a bin's time and count.
- The dropdown uses a stable viewport below the menu bar on the display containing the count. Each opening captures its own fixed screen anchor, so changes in the menu bar count's width or position cannot move the open pane. On small displays, scroll vertically to reach the complete graph content.
- **Reported signal:** SNR in dB from the selected reports' rp field. The box shows the middle 50%, with the median marked. Whiskers end at observed values within 1.5 times the interquartile range. Orange points are outliers. Quartiles use linear interpolation, equivalent to R type 7. Weaker signals are on the left and stronger signals on the right.
- Signal points fade in and out, and the box and whiskers animate as the sample changes. Expired points remain briefly for their fade only. They are already excluded from the count and statistics.
- Missing SNR does not exclude a report from the count. With unique counting enabled, a station whose first report has no valid SNR contributes no signal sample. With it disabled, every report with a valid SNR contributes a signal sample.

### Startup and interruptions

A new connection starts displaying live counts immediately. The window initially contains only reports received since connecting, and the app labels it as filling. There is no historical download.

Changing the callsign, band or mode clears the window and subscribes to the new filter. Changing only the window length keeps the connection. Increasing the length cannot restore history that has already expired, so the longer window fills with subsequent reports.

After a connection failure or sleep, the app reconnects automatically. A warning remains until a full uninterrupted window has been collected. The dropdown labels the old result while disconnected and shows the refilling window after reconnecting. A detected clock change or long pause also resets collection.

| Menu bar | Meaning |
| --- | --- |
| ⛔️ | Stopped or callsign missing/invalid |
| … | Connecting |
| Number | Unique stations or all reports in the current sliding window, as configured |
| ⚠️ | Connection, report or settings error |

Hover for a summary. Settings contains the error time and details, connection status, window coverage and retry time. Stopped or unconfigured status takes precedence in the menu bar, while any settings error remains visible in Settings.

## Feed and filtering

The app connects to mqtt.pskreporter.info:1884 using TLS with system certificate verification. It makes **one sender subscription**, filtered by the broker:

~~~text
pskr/filter/v2/{band}/{mode}/{sending-callsign}/#

All bands and modes: pskr/filter/v2/+/+/ZL1ABC/#
20m, FT8:           pskr/filter/v2/20m/FT8/ZL1ABC/#
~~~

The JSON sender, band and mode are also checked locally. The app does not subscribe to the global feed or poll the database. The feed is provided by Tom M0LTE using PSK Reporter data with permission. This app is an independent client.

CocoaMQTT handles MQTT framing, TLS, keepalive and transport. Failed connections retry after 5 seconds, doubling up to 5 minutes. Collecting a complete uninterrupted window resets the retry delay. TLS verification is never disabled.

Settings use the macOS preferences domain com.tallackn.PSKReporterCounter. Reception data stays in memory and expires with the selected window. No account or API key is required.

## Concurrency and structure

- A dedicated MQTT callback queue decodes and filters reports. Normal report delivery does not dispatch work to the main thread.
- A short lock protects the incoming buffer. A separate serial utility queue owns retained history and calculates the count, histogram and signal statistics. It releases the buffer lock before those calculations.
- The main actor receives a finished, immutable snapshot. Only one calculation can be in flight. Slow refreshes are skipped rather than queued. Results from obsolete connections or settings are ignored.
- Incoming and retained buffers are bounded. Overflow produces a visible error and reconnects instead of silently publishing an incomplete count.
- Chart axes and box marks use Swift Charts. Bars and signal points use batched Canvas drawing with asynchronous rendering enabled, avoiding thousands of individual chart views. Closing the dropdown releases its chart views.

The Build macOS Apps plugin informed the refactor and local build workflow. App/Core contains models, services and monitoring state. App/Counter/Platform contains the small AppKit controllers. App/Counter/Views contains SwiftUI settings and charts. The app has one shared monitoring model. App/Probe contains diagnostics and Tests contains deterministic tests.

## Build and test

Requires Xcode or the Apple Command Line Tools with a compatible macOS SDK. This release was built with Xcode's Swift 6.4 toolchain and macOS 27 SDK. Open Package.swift in Xcode to work on the source.

Clone this repository and build locally:

~~~sh
git clone https://github.com/tallackn/PSKReporterCounter.git
cd PSKReporterCounter
./scripts/build-app.sh
~~~

The development build can use ad hoc signing without the author's credentials. Set PSK_SIGNING_IDENTITY=- to select it explicitly. For a signed Xcode archive, supply your own Apple team and bundle identifier. App Store Connect automation is configured for the author's app and requires that account's credentials; it is not needed to build or use the app.

~~~sh
./scripts/test.sh
./scripts/test.sh --sanitize thread
./script/build_and_run.sh --verify
~~~

The Codex **Run** action uses script/build_and_run.sh. It closes the previous app process, builds, signs and launches the new bundle. Other modes are --debug, --logs and --telemetry. To build without launching, use ./scripts/build-app.sh.

Outputs:

- build/PSK Reporter Counter.app
- build/PSKReporterCounter-arm64.zip

Local development signing prefers an available Apple Development or Developer ID Application identity for Nathan Tallack's team, so sandbox ownership remains stable across rebuilds. It falls back to ad hoc signing if none is available. Set PSK_SIGNING_IDENTITY to choose another local identity, or to - for ad hoc signing. Store exports use Xcode's Apple Distribution signing and a Mac Team Store provisioning profile. Synced project references under sources remain read only.

Every scripted build and archive validates the finished app's licence catalogue against Package.resolved and checks that each notice is complete and matches its source copy. Missing, empty or outdated attribution stops validation. The separate distribution script exports or uploads only when explicitly invoked. App Review and public release remain separate steps.

Every local build also checks the signed App Sandbox and outgoing network entitlements. To exercise sandbox enforcement, preferences across launches and the actual monitoring pipeline, run:

~~~sh
./scripts/check-sandbox.sh YOURCALL 75
~~~

This creates a separate diagnostic app in build. It verifies that an ungranted file outside the container cannot be read, that bundled resources can be read, and that the monitoring model restores saved preferences on a second launch. It then checks live counts and graph data under the same sandbox entitlements. Its preferences are isolated from the user's app settings. The diagnostic is excluded from the app and ZIP.

### Live diagnostics

~~~sh
swift run PSKReporterProbe YOURCALL 45
swift run PSKReporterProbe YOURCALL --monitor 90
~~~

The first command checks a single filtered subscription for 45 seconds. The second runs the app's actual model, timer and threaded pipeline for 90 seconds. It checks that the menu title, histogram total and signal sample count agree. Diagnostic preferences are isolated from the running app. Receiving no reports can be a valid result when that station is not transmitting.

## Dependencies and references

- [CocoaMQTT](https://github.com/emqx/CocoaMQTT), pinned to 2.4.1. Transitive dependencies are pinned by Package.resolved. Licence texts are included in ThirdPartyLicences and in the app.
- [PSK Reporter MQTT feed and payload documentation](https://www.mqtt.pskreporter.info/).
- [PSK Reporter operator's recommendation to use MQTT for programmatic access](https://groups.google.com/g/psk-reporter/c/gkQ3lcwzc6c/m/bWMYXK2wCwAJ).
- [Automated tests](Tests) and [release verification workflow](RELEASE_AUTOMATION.md).
