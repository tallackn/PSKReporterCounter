import AppKit
import Combine
import OSLog
import PSKReporterCore
import SwiftUI

/// AppKit owns the mouse actions and popover. SwiftUI reads the shared monitor.
@MainActor
final class StatusItemController: NSObject, NSPopoverDelegate {
    private let monitor: MonitorModel
    private let openSettings: () -> Void
    private let openAbout: () -> Void
    private let openHelp: () -> Void
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let menu = NSMenu()
    private let popover = NSPopover()
    private let graphDismissal = GraphPopoverDismissal()
    private let logger = Logger(subsystem: "com.tallackn.PSKReporterCounter", category: "MenuBar")
    private var observation: AnyCancellable?
    private var displayedTitle: String?
    private var graphPresentationBounds: NSRect?
    private var graphAnchor: GraphPopoverAnchor?

    init(monitor: MonitorModel, openSettings: @escaping () -> Void,
         openAbout: @escaping () -> Void, openHelp: @escaping () -> Void) {
        self.monitor = monitor
        self.openSettings = openSettings
        self.openAbout = openAbout
        self.openHelp = openHelp
        super.init()
        menu.autoenablesItems = false
        popover.behavior = .applicationDefined
        popover.animates = false
        popover.delegate = self
        if let button = statusItem.button {
            button.font = .systemFont(ofSize: 18)
            button.alignment = .center
            button.target = self
            button.action = #selector(clicked)
            // Resolve each physical click on mouse-down. A later mouse-up must
            // not reopen a pane dismissed while the menu bar takes focus.
            button.sendAction(on: [.leftMouseDown, .rightMouseDown])
            button.setAccessibilityHelp("Left-click for live graphs. Right-click for Settings, About, Help and other commands.")
        }
        observation = monitor.objectWillChange.sink { [weak self] _ in
            DispatchQueue.main.async { self?.updateDisplay() }
        }
        updateDisplay()
    }

    func closeGraphs() { popover.close() }

    func showGraphs() {
        guard !popover.isShown, let button = statusItem.button,
              let window = button.window, let screen = window.screen else { return }
        let buttonFrame = window.convertToScreen(button.convert(button.bounds, to: nil))
        let available = GraphPopoverPlacement.availableFrame(screen: screen.visibleFrame, anchor: buttonFrame)
        guard available.width > 24 && available.height > 24 else { return }
        graphPresentationBounds = available
        let size = GraphPopoverPlacement.contentSize(in: available)
        if popover.contentViewController == nil {
            let hosting = NSHostingController(rootView:
                ScrollView(.vertical) { GraphsPopoverView(monitor: monitor) }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading))
            // AppKit must know the final viewport before it chooses an anchor.
            // Live SwiftUI updates must not resize the popover around that anchor.
            hosting.sizingOptions = []
            hosting.view.setFrameSize(size)
            hosting.preferredContentSize = size
            popover.contentViewController = hosting
        }
        popover.contentSize = size
        popover.contentViewController?.view.layoutSubtreeIfNeeded()
        NSApp.activate(ignoringOtherApps: true)
        let anchor = GraphPopoverAnchor(screenRect: buttonFrame)
        graphAnchor = anchor
        popover.show(relativeTo: anchor.view.bounds, of: anchor.view, preferredEdge: .minY)
        guard popover.isShown else {
            releaseGraphPresentation()
            return
        }
        containGraphsOnScreen()
        button.highlight(true)
        popover.contentViewController?.view.window?.makeKey()
        graphDismissal.start(popover: popover, button: button)
        logger.info("Live graphs opened; visible=\(self.popover.isShown, privacy: .public)")
    }

    private func containGraphsOnScreen() {
        guard popover.isShown, let window = popover.contentViewController?.view.window,
              let available = graphPresentationBounds else { return }
        let frame = GraphPopoverPlacement.containedFrame(window.frame, in: available)
        if window.frame != frame { window.setFrame(frame, display: true) }
    }

    func popoverDidShow(_ notification: Notification) {
        containGraphsOnScreen()
        if let window = popover.contentViewController?.view.window, let available = graphPresentationBounds {
            logger.info("Graph frame \(NSStringFromRect(window.frame), privacy: .public); available \(NSStringFromRect(available), privacy: .public)")
        }
    }

    @objc private func clicked() {
        guard let button = statusItem.button, let window = button.window,
              let screen = window.screen else { return }
        let event = NSApp.currentEvent
        logger.info("Status button action; event=\(String(describing: event?.type), privacy: .public); graphsVisible=\(self.popover.isShown, privacy: .public)")
        if event?.type == .rightMouseDown || event?.modifierFlags.contains(.control) == true {
            closeGraphs()
            rebuildMenu()
            menu.update()
            let buttonFrame = window.convertToScreen(button.convert(button.bounds, to: nil))
            let origin = GraphPopoverPlacement.menuOrigin(button: buttonFrame,
                visibleScreen: screen.visibleFrame, rightToLeft: NSApp.userInterfaceLayoutDirection == .rightToLeft)
            button.highlight(true)
            logger.info("Context menu opened")
            // Supply screen coordinates once. The status button is flipped and
            // can move as its image changes, so it is not a stable menu anchor.
            menu.popUp(positioning: nil, at: origin, in: nil)
            button.highlight(false)
        } else if popover.isShown { closeGraphs() }
        else { showGraphs() }
    }

    func popoverDidClose(_ notification: Notification) {
        releaseGraphPresentation()
        logger.info("Live graphs closed")
    }

    private func releaseGraphPresentation() {
        graphDismissal.stop()
        statusItem.button?.highlight(false)
        // Closed graphs do not observe the monitor or perform hidden redraws.
        popover.contentViewController = nil
        graphPresentationBounds = nil
        graphAnchor?.close()
        graphAnchor = nil
    }

    private func updateDisplay() {
        guard let button = statusItem.button else { return }
        let title = monitor.menuTitle
        if title != displayedTitle {
            logger.debug("Menu display changed to \(title, privacy: .public)")
            if title.allSatisfy({ $0.isNumber }) || title == "⛔️" || title == "⚠️" {
                button.title = ""
                button.image = title.allSatisfy({ $0.isNumber }) ? StatusCountImage.make(title) : StatusCountImage.makeSymbol(title)
                button.imagePosition = .imageOnly
                button.imageScaling = .scaleNone
            } else {
                button.image = nil
                button.imagePosition = .noImage
                button.title = title
            }
            displayedTitle = title
        }
        button.toolTip = monitor.tooltip
        button.setAccessibilityLabel(monitor.tooltip)
        // The popover uses a separate fixed anchor. Its position and viewport
        // remain independent of the status item's changing width and location.
    }

    private func rebuildMenu() {
        menu.removeAllItems()
        addSummary(monitor.statusTitle)
        if let snapshot = monitor.snapshot, monitor.isRunning {
            addSummary("\(snapshot.count) in last \(snapshot.interval.label)")
        }
        menu.addItem(.separator())
        addItem("Settings…", action: #selector(settings), key: ",")
        addItem(monitor.isRunning && monitor.isConfigured ? "Stop Monitoring" : "Start Monitoring", action: #selector(toggleMonitoring))
            .isEnabled = monitor.isConfigured
        addItem("Reconnect", action: #selector(reconnect)).isEnabled = monitor.canReconnect
        menu.addItem(.separator())
        addItem("About PSK Reporter Counter", action: #selector(about))
        addItem("Help…", action: #selector(help))
        menu.addItem(.separator())
        addItem("Quit PSK Reporter Counter", action: #selector(quit), key: "q")
    }

    private func addSummary(_ title: String) {
        let shortened = title.count > 30 ? String(title.prefix(27)) + "..." : title
        let item = NSMenuItem(title: shortened, action: nil, keyEquivalent: "")
        item.isEnabled = false
        menu.addItem(item)
    }

    @discardableResult
    private func addItem(_ title: String, action: Selector, key: String = "") -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: key)
        item.target = self
        menu.addItem(item)
        return item
    }

    @objc private func settings() { closeGraphs(); openSettings() }
    @objc private func about() { closeGraphs(); openAbout() }
    @objc private func help() { closeGraphs(); openHelp() }
    @objc private func toggleMonitoring() { monitor.isRunning ? monitor.stop() : monitor.start() }
    @objc private func reconnect() { monitor.reconnect() }
    @objc private func quit() { NSApp.terminate(nil) }
}
