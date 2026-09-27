import AppKit
import OSLog

/// Own dismissal while the popover is open. A transient popover can close on
/// mouse-down before the status button's mouse-up action, reopening on the same
/// click. Leave clicks on that button to its mouse-down action.
@MainActor
final class GraphPopoverDismissal {
    private var localMonitor: Any?
    private var globalMonitor: Any?
    private var deactivationObserver: NSObjectProtocol?
    private let logger = Logger(subsystem: "com.tallackn.PSKReporterCounter", category: "MenuBar")

    func start(popover: NSPopover, button: NSStatusBarButton) {
        stop()
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown, .otherMouseDown, .keyDown]) {
            [weak popover, weak button] event in
            guard let popover, popover.isShown else { return event }
            if event.type == .keyDown {
                if event.keyCode == 53 { popover.close(); return nil }
                return event
            }
            if event.window === popover.contentViewController?.view.window { return event }
            let point = event.window?.convertPoint(toScreen: event.locationInWindow) ?? NSEvent.mouseLocation
            if Self.contains(point, button: button) { return event }
            popover.close()
            return event
        }
        // Mouse-only monitoring does not require Accessibility permission.
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown, .otherMouseDown]) {
            [weak popover, weak button] _ in
            guard !Self.contains(NSEvent.mouseLocation, button: button) else { return }
            popover?.close()
        }
        deactivationObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didResignActiveNotification, object: NSApp, queue: .main
        ) { [weak self, weak popover, weak button] _ in
            MainActor.assumeIsolated {
                // Clicking a status item can deactivate the app before its
                // button action arrives. Let that action close the pane once.
                if NSEvent.pressedMouseButtons != 0 && Self.contains(NSEvent.mouseLocation, button: button) {
                    self?.logger.info("Deactivation during status button press; retaining graphs for the button action")
                    return
                }
                self?.logger.info("Closing graphs after application deactivation")
                popover?.close()
            }
        }
    }

    func stop() {
        if let localMonitor { NSEvent.removeMonitor(localMonitor) }
        if let globalMonitor { NSEvent.removeMonitor(globalMonitor) }
        if let deactivationObserver { NotificationCenter.default.removeObserver(deactivationObserver) }
        localMonitor = nil
        globalMonitor = nil
        deactivationObserver = nil
    }

    private static func contains(_ point: NSPoint, button: NSStatusBarButton?) -> Bool {
        guard let button, let window = button.window else { return false }
        return window.convertToScreen(button.convert(button.bounds, to: nil)).contains(point)
    }
}
