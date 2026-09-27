import AppKit
import OSLog
import PSKReporterCore
import SwiftUI

@MainActor
final class SettingsWindowController: NSWindowController {
    private let logger = Logger(subsystem: "com.tallackn.PSKReporterCounter", category: "Windowing")

    init(monitor: MonitorModel, login: LoginItemController) {
        let hosting = NSHostingController(rootView: SettingsView(monitor: monitor, login: login))
        let window = NSWindow(contentViewController: hosting)
        window.title = "PSK Reporter Counter — Settings"
        window.styleMask = [.titled, .closable, .miniaturizable]
        window.isReleasedWhenClosed = false
        let availableHeight = NSScreen.main?.visibleFrame.height ?? 840
        window.setContentSize(NSSize(width: 620, height: max(420, min(780, availableHeight - 60))))
        window.center()
        super.init(window: window)
    }

    required init?(coder: NSCoder) { nil }

    func show() {
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        logger.info("Settings opened")
    }
}
