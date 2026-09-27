import Foundation

struct HelpSection: Identifiable {
    let title: String
    let body: String
    var id: String { title }
}

enum HelpTopic: String, CaseIterable, Identifiable {
    case gettingStarted, menuBar, liveWindow, counting, graphs, settings, troubleshooting, privacy
    var id: String { rawValue }

    var title: String {
        switch self {
        case .gettingStarted: "Getting started"
        case .menuBar: "Menu bar controls"
        case .liveWindow: "The live window"
        case .counting: "Counting reports"
        case .graphs: "Reading the graphs"
        case .settings: "Settings and startup"
        case .troubleshooting: "Troubleshooting"
        case .privacy: "Data and privacy"
        }
    }

    var symbol: String {
        switch self {
        case .gettingStarted: "play.circle"
        case .menuBar: "menubar.rectangle"
        case .liveWindow: "clock"
        case .counting: "number"
        case .graphs: "chart.bar.xaxis"
        case .settings: "gearshape"
        case .troubleshooting: "exclamationmark.triangle"
        case .privacy: "hand.raised"
        }
    }

    func matches(_ search: String) -> Bool {
        let query = search.trimmingCharacters(in: .whitespacesAndNewlines)
        return query.isEmpty || title.localizedCaseInsensitiveContains(query)
            || sections.contains { $0.title.localizedCaseInsensitiveContains(query) || $0.body.localizedCaseInsensitiveContains(query) }
    }

    var sections: [HelpSection] {
        switch self {
        case .gettingStarted:
            [
                HelpSection(title: "Set up your station", body: "1. Open PSK Reporter Counter. Settings opens automatically when no callsign is saved.\n\n2. Enter the transmitting callsign you want to follow. Use the full callsign reported by your radio software, including any portable suffix.\n\n3. Choose a window length. The default is 15 minutes. Leave Band and Mode at All unless you want a narrower view.\n\n4. Leave Count unique stations enabled to count each receiving station once, or turn it off to count every report.\n\n5. Select Save and Start. Reports begin appearing as the live feed delivers them."),
                HelpSection(title: "View reception activity", body: "Left-click the menu bar item for the live graphs. Right-click, or Control-click, for Settings and the other commands. Once a valid callsign is saved, the listener starts automatically whenever you launch the app."),
                HelpSection(title: "Allow the window to fill", body: "The app starts with reports received since connecting. It does not download older reports. The initial count can be zero even while you are transmitting. Leave it running while the window fills.")
            ]
        case .menuBar:
            [
                HelpSection(title: "Left-click: live graphs", body: "Open or close the graph dropdown. The counter and both graphs update once per second while monitoring is active. Click elsewhere or press Escape to dismiss the dropdown."),
                HelpSection(title: "Right-click: commands", body: "Settings changes the callsign, window, filters and startup options. Stop Monitoring pauses this session. Start Monitoring resumes it. Reconnect starts a fresh connection and collection window. About shows the author, version, credits and full licences. Help opens this guide. Quit closes the app and listener."),
                HelpSection(title: "What the display means", body: "A number is the count in the current sliding window. Zero means no matching reports remain in that window.\n\n… means the app is connecting.\n\n⛔️ means monitoring is stopped or a valid callsign has not been configured.\n\n⚠️ means there is a connection, report or settings error. Hover over the item for a summary and open Settings for details.")
            ]
        case .liveWindow:
            [
                HelpSection(title: "Always the most recent interval", body: "A 15-minute window shows reports that arrived during the last 15 minutes. The time range moves forward every second. New reports enter on the right of the arrival graph, and old reports leave at the left. The count can fall without a connection problem when earlier reports expire."),
                HelpSection(title: "Arrival time", body: "PSK Reporter reports can reach the app after a delay. This app counts them when they arrive, regardless of when the transmission was received. That is why its count can differ from the PSK Reporter map, which can show a different period based on reception times."),
                HelpSection(title: "Changing the window or filters", body: "Changing only the window length recalculates the retained reports. Increasing it cannot recover reports that have already expired, so the longer window fills over time. Changing the callsign, band or mode starts a fresh subscription and clears the collected window."),
                HelpSection(title: "Sleep and interruptions", body: "Reports cannot be collected while the Mac is asleep or disconnected. The app reconnects after waking or a connection failure. A warning remains until it has collected a complete uninterrupted window. The graphs show that the window is refilling.")
            ]
        case .counting:
            [
                HelpSection(title: "Count unique stations: on", body: "This is the default. Each receiving callsign counts once within the current window. Its first report in the window supplies the time and signal measurement used by the graphs. Repeated reports do not increase the count. When the first report expires, a later report from the same station can keep that station in the window."),
                HelpSection(title: "Count unique stations: off", body: "Every matching report counts, including repeated reports from one receiving station. Each report with a valid signal measurement contributes to the box plot. This shows report volume rather than the number of different stations."),
                HelpSection(title: "Change counting mode", body: "Open Settings, change Count unique stations and select Apply. The counter and both graphs recalculate from the reports already collected. The connection stays active. The choice is saved for the next launch."),
                HelpSection(title: "Bands and modes", body: "All bands and All modes include every matching report for the transmitting callsign. With unique counting enabled, a station heard on several bands or modes still counts once across the whole window.")
            ]
        case .graphs:
            [
                HelpSection(title: "Arrivals", body: "Each bar represents one second of report arrivals, using the counting mode selected in Settings. The sum of the bars equals the menu bar count. Hover over the chart for the time and count of a bin. The right edge is the current time."),
                HelpSection(title: "Detail", body: "Select Detail to expand the arrival chart and scroll horizontally through individual seconds. Longer windows retain one-second bins. Turn Detail off to return to the complete window."),
                HelpSection(title: "Reported signal", body: "The box plot shows reported signal-to-noise ratio (SNR) in dB. Weaker signals are on the left, and stronger signals on the right. More negative values mean a weaker reported signal. Compare like modes where possible because different reporting software and modes may measure SNR differently."),
                HelpSection(title: "Box, whiskers and points", body: "The box contains the middle half of the measurements. Its central line is the median. The whiskers extend to the most extreme measurements within 1.5 times the interquartile range. Orange points are outliers. New points appear and expired points fade away while the box and whiskers adjust."),
                HelpSection(title: "Missing signal measurements", body: "Reports without a valid SNR still contribute to the count. With unique counting on, only the first report per station is considered, even if a later report includes SNR. The sample total below the box plot can therefore be smaller than the menu bar count.")
            ]
        case .settings:
            [
                HelpSection(title: "Monitoring options", body: "Callsign identifies the sending station. Window length supports 1, 5, 10, 15, 30, 60 and 120 minutes. Band and Mode limit which reports are received. Count unique stations chooses between distinct stations and all reports. Select Apply after changing these options."),
                HelpSection(title: "Hide Dock icon", body: "This takes effect immediately. The menu bar item remains available. Right-click it to open Settings, About or Help. Closing a window leaves the listener running."),
                HelpSection(title: "Launch automatically at login", body: "Install the app in Applications, then enable this option. If macOS requests approval, open System Settings > General > Login Items and allow PSK Reporter Counter. The status in Settings shows whether it is enabled or needs approval."),
                HelpSection(title: "Stop and quit", body: "Stop Monitoring pauses the current session. Launching the app again starts the listener when a valid callsign is saved. Quit stops the app completely. Closing Settings, About or Help does not quit."),
                HelpSection(title: "Keyboard access", body: "With the app active, Command-comma opens Settings, Command-G opens Live Graphs, Command-question mark opens Help, Command-W closes the current window and Command-Q quits. Control-click is an alternative to right-click on the menu bar item.")
            ]
        case .troubleshooting:
            [
                HelpSection(title: "The count is zero", body: "Confirm the transmitting callsign, including any suffix, and try All bands and All modes. Allow time for reception reports to arrive and the window to fill. Look at Last report arrived in Settings. A station must submit its reception to PSK Reporter for the report to reach this app. The map may contain older receptions that this session has never received."),
                HelpSection(title: "The warning symbol appears", body: "Hover for the short error and open Settings for the full status. Check your internet connection. A network or firewall must allow the secure live feed at mqtt.pskreporter.info on TCP port 1884. The app retries automatically. Reconnect lets you try again and begins a fresh window."),
                HelpSection(title: "Connected, but the warning remains", body: "After an interruption the app keeps the warning until a whole selected window has been collected continuously. The count and graphs can update while that window is refilling. Settings shows when full coverage will be available."),
                HelpSection(title: "The stopped symbol appears", body: "Enter a valid callsign and select Save and Start. If monitoring was paused, choose Start Monitoring from the right-click menu. Callsigns must contain letters and numbers; portable suffixes using / or - are supported."),
                HelpSection(title: "A startup setting needs attention", body: "Read the detailed error in Settings. Keep the app in Applications and check macOS Login Items approval. Resolve the setting, then dismiss its settings error if appropriate.")
            ]
        case .privacy:
            [
                HelpSection(title: "What connects to the network", body: "The app makes one encrypted connection to the PSK Reporter MQTT feed and subscribes to the selected transmitting callsign, band and mode. Those subscription choices, your IP address and a random connection identifier are available to the feed provider. Its public documentation does not specify retention of connection details. Use the Privacy policy link below for more information. It does not request the global stream or poll the PSK Reporter database."),
                HelpSection(title: "What is stored", body: "The callsign and preferences are saved on your Mac. Reception reports remain in memory and expire with the window. Restarting the app starts with an empty history. The app does not upload your reception history or include an analytics service. Basic lifecycle and error events can appear in macOS diagnostic logs."),
                HelpSection(title: "Accounts and external links", body: "No account or API key is needed. Help and licence text are available offline. Opening the PSK Reporter or project links uses your browser and the destination site's own terms.")
            ]
        }
    }
}
