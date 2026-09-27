import AppKit
import OSLog
import SwiftUI

/// A small bridge for reusable utility windows on the macOS 13 deployment target.
@MainActor
final class InformationWindowController<Content: View>: NSWindowController {
    private let logger = Logger(subsystem: "com.tallackn.PSKReporterCounter", category: "Windowing")

    init(title: String, size: NSSize, content: Content) {
        let window = NSWindow(contentViewController: NSHostingController(rootView: content))
        window.title = title
        window.styleMask = [.titled, .closable, .resizable]
        window.isReleasedWhenClosed = false
        window.isRestorable = false
        window.collectionBehavior = [.fullScreenNone]
        let visible = NSScreen.main?.visibleFrame.size ?? NSSize(width: 1024, height: 768)
        let fitted = NSSize(width: min(size.width, visible.width - 40), height: min(size.height, visible.height - 60))
        window.setContentSize(fitted)
        window.contentMinSize = NSSize(width: min(620, fitted.width), height: min(420, fitted.height))
        window.center()
        super.init(window: window)
    }

    required init?(coder: NSCoder) { nil }

    func show() {
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        logger.info("Information window opened: \(self.window?.title ?? "", privacy: .public)")
    }
}
