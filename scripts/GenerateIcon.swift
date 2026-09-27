import AppKit

let destination = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: true)

func render(size: Int) -> Data {
    let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: size, pixelsHigh: size,
        bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
        colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
    let scale = Double(size) / 1024
    let transform = NSAffineTransform()
    transform.scale(by: scale)
    transform.concat()
    let background = NSBezierPath(roundedRect: NSRect(x: 70, y: 70, width: 884, height: 884), xRadius: 198, yRadius: 198)
    NSGradient(starting: NSColor(srgbRed: 0.08, green: 0.39, blue: 0.77, alpha: 1),
               ending: NSColor(srgbRed: 0.02, green: 0.16, blue: 0.40, alpha: 1))!.draw(in: background, angle: -80)
    NSColor.white.setStroke()
    NSColor.white.setFill()
    let mast = NSBezierPath()
    mast.lineWidth = 44
    mast.lineCapStyle = .round
    mast.move(to: NSPoint(x: 512, y: 300))
    mast.line(to: NSPoint(x: 512, y: 525))
    mast.stroke()
    NSBezierPath(ovalIn: NSRect(x: 470, y: 505, width: 84, height: 84)).fill()
    for radius: CGFloat in [140, 242] {
        for angles: (CGFloat, CGFloat) in [(137, 223), (-43, 43)] {
            let wave = NSBezierPath()
            wave.lineWidth = 36
            wave.lineCapStyle = .round
            wave.appendArc(withCenter: NSPoint(x: 512, y: 548), radius: radius, startAngle: angles.0, endAngle: angles.1)
            wave.stroke()
        }
    }
    let base = NSBezierPath()
    base.lineWidth = 35
    base.lineCapStyle = .round
    base.move(to: NSPoint(x: 418, y: 278))
    base.line(to: NSPoint(x: 606, y: 278))
    base.stroke()
    NSColor(srgbRed: 0.35, green: 0.9, blue: 0.8, alpha: 1).setFill()
    NSBezierPath(ovalIn: NSRect(x: 715, y: 162, width: 115, height: 115)).fill()
    NSGraphicsContext.restoreGraphicsState()
    return bitmap.representation(using: .png, properties: [:])!
}

for size in [16, 32, 128, 256, 512] {
    try render(size: size).write(to: destination.appendingPathComponent("icon_\(size)x\(size).png"))
    try render(size: size * 2).write(to: destination.appendingPathComponent("icon_\(size)x\(size)@2x.png"))
}
