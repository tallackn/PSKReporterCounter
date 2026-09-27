# PSK Reporter Counter

A native macOS menu bar app written in Swift, using AppKit, SwiftUI, Swift Charts and CocoaMQTT. Version 2.0 targets Apple silicon and macOS 13 or later.

## Build and install locally

Requires an Apple silicon Mac running macOS 13 or later, and Xcode or the Apple Command Line Tools with a compatible Swift toolchain and macOS SDK. The current build is verified with Swift 6.4 and the macOS 27 SDK.

```sh
git clone https://github.com/tallackn/PSKReporterCounter.git
cd PSKReporterCounter
PSK_SIGNING_IDENTITY=- ./scripts/build-app.sh
```

The script builds the app, bundles its resources and licences, and signs it for local use. It produces:

- `build/PSK Reporter Counter.app`
- `build/PSKReporterCounter-arm64.zip`

Quit any running copy, then copy **PSK Reporter Counter.app** from the build folder to **Applications** and open it. For subsequent updates, rebuild and replace the app in Applications after quitting it. Settings are stored separately from the app bundle.

The `-` signing identity uses ad hoc signing and needs no Apple developer account. To use your own installed signing identity, set `PSK_SIGNING_IDENTITY` to its name or fingerprint. Use the same identity across rebuilds to preserve sandbox access consistently.

## Use

Enter the **transmitting callsign**, choose the window length, band and mode, then select **Save and Start** or **Apply**.

- **Left-click** the menu bar count to open or close the live graphs. They continue updating while the dropdown is open. Clicking outside the pane or pressing Escape also closes it.
- **Right-click**, or Control-click, for Settings, Start/Stop Monitoring, Reconnect, About, Help and Quit.
- Closing Settings leaves monitoring running. Hide Dock icon takes effect immediately.
- A saved valid callsign starts listening automatically on every launch. **Stop Monitoring** pauses the current session only.
- Move the app to **Applications** before enabling **Launch automatically at login**. macOS may require approval in **System Settings > General > Login Items**. The app reads the actual system login item state.

## About and Help

**About PSK Reporter Counter** shows the version, author **Nathan Tallack (ZL2NU)**, data service credits and an offline licence reader. Choose **Licences**, then a component to read its full notices. About is available from the right-click menu and the app's main menu.

**Help** opens a searchable guide covering setup, menu bar controls, sliding windows, counting modes, graph interpretation, startup options, troubleshooting and privacy. It works offline. Open it from the right-click menu, the main Help menu or Command-question mark while the app is active. The guide includes an Open Settings button.

The original app source and documentation are released under the [MIT License](LICENSE). Third-party components retain their own terms. The complete inventory and provenance are in [ThirdPartyLicences/README.md](ThirdPartyLicences/README.md). **Source code on GitHub** in About opens [tallackn/PSKReporterCounter](https://github.com/tallackn/PSKReporterCounter).

## Sandbox and privacy

App Sandbox allows outgoing network connections for the live feed. Preferences use the app container, and the app requests no user document access. Reception data stays in memory and expires with the selected window. No account or API key is required.

The privacy manifest declares UserDefaults access for the app's own preferences. CocoaMQTT retains its separate bundled manifest. Read the [privacy policy](PRIVACY.md) for what is sent to the independent feed provider and see [Support](SUPPORT.md) for help.

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

Settings use the macOS preferences domain `com.tallackn.PSKReporterCounter`.

## Concurrency and structure

- A dedicated MQTT callback queue decodes and filters reports. Normal report delivery does not dispatch work to the main thread.
- A short lock protects the incoming buffer. A separate serial utility queue owns retained history and calculates the count, histogram and signal statistics. It releases the buffer lock before those calculations.
- The main actor receives a finished, immutable snapshot. Only one calculation can be in flight. Slow refreshes are skipped rather than queued. Results from obsolete connections or settings are ignored.
- Incoming and retained buffers are bounded. Overflow produces a visible error and reconnects instead of silently publishing an incomplete count.
- Chart axes and box marks use Swift Charts. Bars and signal points use batched Canvas drawing with asynchronous rendering enabled, avoiding thousands of individual chart views. Closing the dropdown releases its chart views.

App/Core contains models, services and monitoring state. App/Counter/Platform contains the small AppKit controllers. App/Counter/Views contains SwiftUI settings and charts. The app has one shared monitoring model. App/Probe contains diagnostics and Tests contains deterministic tests.

## Development and tests

Open `Package.swift` in Xcode to work on the Swift package. The native application project, `PSKReporterCounter.xcodeproj`, uses the same app and core sources.

```sh
./scripts/test.sh
./scripts/test.sh --sanitize thread
./scripts/check-popover-placement.sh
./scripts/check-popover-anchor.sh
```

The placement checks cover several display sizes and arrangements. The native anchor check briefly opens a separate diagnostic pane, changes its menu bar item's width and checks that the pane stays fixed. It requires an interactive macOS desktop. Add `--interactive` to check left-click toggling, right-click menu placement, outside-click dismissal and Escape manually, then choose **Finish check** from its right-click menu.

For a build-and-run development cycle:

```sh
PSK_SIGNING_IDENTITY=- ./script/build_and_run.sh --verify
```

This closes the previous app process, builds, signs and launches the new bundle. Other modes are `--debug`, `--logs` and `--telemetry`. To build without launching, use `./scripts/build-app.sh`.

Every scripted build validates the finished app's licence catalogue against `Package.resolved` and checks that each notice is complete and matches its source copy. Missing, empty or outdated attribution stops validation.

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
- [Automated tests](Tests).
