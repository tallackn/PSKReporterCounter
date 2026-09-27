import AppKit
import CoreText

enum StatusCountImage {
    static func make(_ count: String) -> NSImage {
        makeText(count, colour: false)
    }

    static func makeSymbol(_ symbol: String) -> NSImage {
        makeText(symbol, colour: true)
    }

    private static func makeText(_ textValue: String, colour: Bool) -> NSImage {
        let font = NSFont.monospacedDigitSystemFont(ofSize: 18, weight: .medium)
        let text = NSAttributedString(string: textValue, attributes: [
            .font: font,
            .foregroundColor: NSColor.black
        ])
        let line = CTLineCreateWithAttributedString(text)
        let bounds = CTLineGetBoundsWithOptions(line, .useGlyphPathBounds)
        let size = NSSize(width: max(20, ceil(bounds.width) + 4), height: 20)
        let image = NSImage(size: size, flipped: false) { _ in
            guard let context = NSGraphicsContext.current?.cgContext else { return false }
            context.saveGState()
            context.textMatrix = .identity
            // Centre the visible glyphs rather than the font's line box,
            // which includes unused space for ascenders and descenders.
            context.textPosition = CGPoint(
                x: (size.width - bounds.width) / 2 - bounds.minX,
                y: (size.height - bounds.height) / 2 - bounds.minY
            )
            CTLineDraw(line, context)
            context.restoreGState()
            return true
        }
        image.isTemplate = !colour
        return image
    }
}
