import AppKit
import SwiftUI

@MainActor
private final class Samples: ObservableObject {
    @Published var text = "0"
}

private struct RefreshingContent: View {
    @ObservedObject var samples: Samples
    var body: some View {
        VStack(alignment: .leading) {
            Text("Graph position regression check").font(.headline)
            Text(samples.text).font(.largeTitle)
            Text("The menu bar count changes width while this pane stays still.")
            Spacer()
        }.padding(20).frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

@MainActor
private final class AnchorCheck: NSObject, NSApplicationDelegate {
    private let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let popover = NSPopover()
    private let samples = Samples()
    private var anchor: GraphPopoverAnchor?
    private var initialFrame = NSRect.zero
    private var initialAnchor = NSRect.zero
    private var measuredFrames: [String] = []
    private var buttonFrames = Set<String>()
    private let values = ["1", "8", "11", "88", "99", "100", "888", "9999", "10000", "0"]
    private var index = 0

    func applicationDidFinishLaunching(_ notification: Notification) {
        item.button?.image = StatusCountImage.make("0")
        // Wait for the status bar host to lay out this newly created item.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { [self] in openPopover() }
        DispatchQueue.main.asyncAfter(deadline: .now() + 20) { [self] in
            finish(error: "The native check did not finish within 20 seconds.")
        }
    }

    private func openPopover() {
        guard let button = item.button, let window = button.window, let screen = window.screen else {
            finish(error: "No menu bar display is available.")
            return
        }
        button.image = StatusCountImage.make("0")
        let rect = window.convertToScreen(button.convert(button.bounds, to: nil))
        let available = GraphPopoverPlacement.availableFrame(screen: screen.visibleFrame, anchor: rect)
        guard available.width > 24 && available.height > 24 else {
            finish(error: "The status bar has not supplied a usable screen frame: \(NSStringFromRect(rect)).")
            return
        }
        let size = GraphPopoverPlacement.contentSize(in: available)
        let hosting = NSHostingController(rootView: RefreshingContent(samples: samples))
        hosting.sizingOptions = []
        hosting.view.setFrameSize(size)
        hosting.preferredContentSize = size
        popover.contentViewController = hosting
        popover.contentSize = size
        popover.animates = false
        popover.behavior = .transient
        NSApp.activate(ignoringOtherApps: true)
        anchor = GraphPopoverAnchor(screenRect: rect)
        popover.show(relativeTo: anchor!.view.bounds, of: anchor!.view, preferredEdge: .minY)
        guard let pane = hosting.view.window, popover.isShown else {
            finish(error: "The native popover did not open.")
            return
        }
        let contained = GraphPopoverPlacement.containedFrame(pane.frame, in: available)
        if pane.frame != contained { pane.setFrame(contained, display: true) }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [self] in
            initialFrame = pane.frame
            initialAnchor = anchor!.view.window!.frame
            changeSample()
        }
    }

    private func changeSample() {
        let value = values[index % values.count]
        item.button?.image = StatusCountImage.make(value)
        // Exercise shifts caused by other status items as well as digit width.
        item.length = index.isMultiple(of: 2) ? 80 : NSStatusItem.variableLength
        samples.text = index.isMultiple(of: 3) ? String(repeating: value + " ", count: 30) : value
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.06) { [self] in
            guard popover.isShown, let pane = popover.contentViewController?.view.window,
                  let fixed = anchor?.view.window else {
                finish(error: "The popover was dismissed during the check.")
                return
            }
            measuredFrames.append(NSStringFromRect(pane.frame))
            if let frame = item.button?.window?.frame { buttonFrames.insert(NSStringFromRect(frame)) }
            guard pane.frame == initialFrame, fixed.frame == initialAnchor else {
                finish(error: "The popover or its fixed anchor moved during a refresh.")
                return
            }
            index += 1
            if index < 50 { changeSample() }
            else { finish(error: buttonFrames.count > 1 ? nil : "The test did not move the status item.") }
        }
    }

    private func finish(error: String?) {
        let result: [String: Any] = ["passed": error == nil, "error": error ?? "",
            "refreshes": measuredFrames.count, "distinctButtonFrames": buttonFrames.count,
            "distinctPopoverFrames": Set(measuredFrames).count, "frame": NSStringFromRect(initialFrame)]
        if CommandLine.arguments.count > 1,
           let data = try? JSONSerialization.data(withJSONObject: result, options: [.prettyPrinted, .sortedKeys]) {
            try? data.write(to: URL(fileURLWithPath: CommandLine.arguments[1]))
        }
        popover.close()
        anchor?.close()
        NSStatusBar.system.removeStatusItem(item)
        NSApp.terminate(nil)
    }
}

@main
enum PopoverAnchorCheck {
    @MainActor static func main() {
        let app = NSApplication.shared
        app.setActivationPolicy(.accessory)
        let check = AnchorCheck()
        app.delegate = check
        withExtendedLifetime(check) { app.run() }
    }
}
