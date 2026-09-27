import CoreGraphics

/// Screen coordinates use an upward y axis. All placement is relative to the
/// screen containing the status button, including screens with negative origins.
enum GraphPopoverPlacement {
    static func availableFrame(screen: CGRect, anchor: CGRect) -> CGRect {
        let top = min(screen.maxY, anchor.minY)
        return CGRect(x: screen.minX, y: screen.minY, width: screen.width,
                      height: max(0, top - screen.minY)).insetBy(dx: 8, dy: 8)
    }

    static func contentSize(in available: CGRect) -> CGSize {
        // Reserve space for the system popover border and arrow. SwiftUI's
        // scroll view handles any content taller than this stable viewport.
        CGSize(width: max(1, min(640, available.width - 24)),
               height: max(1, min(660, available.height - 24)))
    }

    static func containedFrame(_ proposed: CGRect, in available: CGRect) -> CGRect {
        let width = min(proposed.width, available.width)
        let height = min(proposed.height, available.height)
        return CGRect(x: max(available.minX, min(proposed.minX, available.maxX - width)),
                      y: max(available.minY, min(proposed.minY, available.maxY - height)),
                      width: width, height: height)
    }
}
