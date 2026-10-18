import AppKit

// Original artwork: a friendly ox-shaped message bubble.
let output = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
func render(_ pixels: Int) -> Data {
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels, bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    let transform = NSAffineTransform()
    transform.scale(by: CGFloat(pixels) / 1024)
    transform.concat()
    let tile = NSBezierPath(roundedRect: NSRect(x: 70, y: 70, width: 884, height: 884), xRadius: 198, yRadius: 198)
    NSGraphicsContext.saveGraphicsState()
    let shadow = NSShadow()
    shadow.shadowColor = NSColor.black.withAlphaComponent(0.18)
    shadow.shadowBlurRadius = 28
    shadow.shadowOffset = NSSize(width: 0, height: -12)
    shadow.set()
    NSColor.systemBlue.setFill()
    tile.fill()
    NSGraphicsContext.restoreGraphicsState()
    NSGradient(starting: NSColor(srgbRed: 0.08, green: 0.34, blue: 0.93, alpha: 1), ending: NSColor(srgbRed: 0.2, green: 0.65, blue: 1, alpha: 1))!.draw(in: tile, angle: 60)
    NSColor.white.setFill()
    let horns = NSBezierPath()
    horns.move(to: NSPoint(x: 368, y: 661))
    horns.curve(to: NSPoint(x: 224, y: 815), controlPoint1: NSPoint(x: 236, y: 670), controlPoint2: NSPoint(x: 219, y: 734))
    horns.curve(to: NSPoint(x: 333, y: 730), controlPoint1: NSPoint(x: 265, y: 748), controlPoint2: NSPoint(x: 292, y: 733))
    horns.line(to: NSPoint(x: 400, y: 705))
    horns.close()
    horns.fill()
    let mirror = NSAffineTransform()
    mirror.translateX(by: 1024, yBy: 0)
    mirror.scaleX(by: -1, yBy: 1)
    horns.transform(using: mirror as AffineTransform)
    horns.fill()
    let bubble = NSBezierPath(roundedRect: NSRect(x: 267, y: 300, width: 490, height: 420), xRadius: 144, yRadius: 144)
    bubble.fill()
    let tail = NSBezierPath()
    tail.move(to: NSPoint(x: 338, y: 362))
    tail.line(to: NSPoint(x: 302, y: 223))
    tail.curve(to: NSPoint(x: 462, y: 321), controlPoint1: NSPoint(x: 382, y: 238), controlPoint2: NSPoint(x: 425, y: 277))
    tail.close()
    tail.fill()
    NSColor(srgbRed: 0.12, green: 0.45, blue: 0.96, alpha: 1).setFill()
    for x in [390.0, 580.0] { NSBezierPath(roundedRect: NSRect(x: x, y: 485, width: 54, height: 72), xRadius: 27, yRadius: 27).fill() }
    let smile = NSBezierPath()
    smile.move(to: NSPoint(x: 445, y: 417))
    smile.curve(to: NSPoint(x: 579, y: 417), controlPoint1: NSPoint(x: 480, y: 385), controlPoint2: NSPoint(x: 544, y: 385))
    smile.lineWidth = 20
    smile.lineCapStyle = .round
    NSColor(srgbRed: 0.12, green: 0.45, blue: 0.96, alpha: 1).setStroke()
    smile.stroke()
    NSGraphicsContext.restoreGraphicsState()
    return rep.representation(using: .png, properties: [:])!
}
for size in [16, 32, 128, 256, 512] {
    try render(size).write(to: output.appendingPathComponent("icon_\(size)x\(size).png"))
    try render(size * 2).write(to: output.appendingPathComponent("icon_\(size)x\(size)@2x.png"))
}
