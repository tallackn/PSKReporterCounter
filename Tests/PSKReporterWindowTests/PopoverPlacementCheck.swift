import CoreGraphics

/// Exercise the production geometry without opening a development app or
/// changing the display configuration used for the TestFlight UX check.
@main
enum PopoverPlacementCheck {
    static func main() {
        let screens: [CGRect] = [
            CGRect(x: 0, y: 70, width: 2560, height: 1345),
            CGRect(x: 0, y: 55, width: 1280, height: 720),
            CGRect(x: -1920, y: 0, width: 1920, height: 1055),
            CGRect(x: 2560, y: 0, width: 900, height: 1415),
            CGRect(x: 0, y: -1080, width: 1920, height: 1055),
            CGRect(x: 0, y: 1440, width: 1920, height: 1055),
            CGRect(x: 0, y: 0, width: 600, height: 360)
        ]
        var cases = 0
        for screen in screens {
            for anchorX in [screen.minX + 10, screen.midX, screen.maxX - 30] {
                let anchor = CGRect(x: anchorX, y: screen.maxY, width: 22, height: 25)
                let available = GraphPopoverPlacement.availableFrame(screen: screen, anchor: anchor)
                let content = GraphPopoverPlacement.contentSize(in: available)
                precondition(content.width > 0 && content.height > 0)
                precondition(content.width + 24 <= available.width)
                precondition(content.height + 24 <= available.height)
                // Include an initially oversized window and a window shifted
                // above the menu bar, as reported in the first TestFlight build.
                for size in [CGSize(width: 668, height: 688),
                             CGSize(width: content.width + 20, height: content.height + 20)] {
                    for offset in [-700.0, 0, 700] {
                        let proposed = CGRect(x: anchor.midX - size.width / 2 + offset,
                                              y: anchor.minY - size.height + offset,
                                              width: size.width, height: size.height)
                        let placed = GraphPopoverPlacement.containedFrame(proposed, in: available)
                        precondition(screen.contains(placed), "Popover extends outside its display")
                        precondition(placed.maxY < anchor.minY, "Popover covers or crosses the menu bar")
                        precondition(placed.width > 0 && placed.height > 0)
                        precondition(GraphPopoverPlacement.containedFrame(placed, in: available) == placed,
                                     "Repeated live updates must not move an already contained window")
                        cases += 1
                    }
                }
            }
        }
        print("Passed \(cases) popover placement cases across seven display layouts, including small and vertically stacked displays.")
    }
}
