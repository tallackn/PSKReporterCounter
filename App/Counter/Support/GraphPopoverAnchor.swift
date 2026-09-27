import AppKit

/// NSPopover follows its positioning view automatically. Give each opening a
/// separate, stationary view so changes to the status item cannot move it.
@MainActor
final class GraphPopoverAnchor {
    private let window: NSWindow
    let view: NSView

    init(screenRect: NSRect) {
        window = NSWindow(contentRect: screenRect, styleMask: .borderless,
                          backing: .buffered, defer: false)
        view = NSView(frame: NSRect(origin: .zero, size: screenRect.size))
        window.contentView = view
        window.isReleasedWhenClosed = false
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = false
        window.ignoresMouseEvents = true
        window.isExcludedFromWindowsMenu = true
        window.animationBehavior = .none
        window.level = .statusBar
        window.collectionBehavior = [.transient, .moveToActiveSpace, .fullScreenAuxiliary]
        window.setFrame(screenRect, display: false)
        window.orderFront(nil)
    }

    func close() { window.close() }
}
