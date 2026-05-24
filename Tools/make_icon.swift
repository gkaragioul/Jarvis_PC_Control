import AppKit

let output = CommandLine.arguments.dropFirst().first ?? "Resources/AppIcon.iconset"
let outputURL = URL(fileURLWithPath: output)
try? FileManager.default.removeItem(at: outputURL)
try FileManager.default.createDirectory(at: outputURL, withIntermediateDirectories: true)

let specs: [(String, CGFloat)] = [
    ("icon_16x16.png", 16),
    ("icon_16x16@2x.png", 32),
    ("icon_32x32.png", 32),
    ("icon_32x32@2x.png", 64),
    ("icon_128x128.png", 128),
    ("icon_128x128@2x.png", 256),
    ("icon_256x256.png", 256),
    ("icon_256x256@2x.png", 512),
    ("icon_512x512.png", 512),
    ("icon_512x512@2x.png", 1024),
]

func color(_ hex: UInt32, alpha: CGFloat = 1) -> NSColor {
    NSColor(
        calibratedRed: CGFloat((hex >> 16) & 0xff) / 255,
        green: CGFloat((hex >> 8) & 0xff) / 255,
        blue: CGFloat(hex & 0xff) / 255,
        alpha: alpha
    )
}

func circle(center: CGPoint, radius: CGFloat) -> NSBezierPath {
    NSBezierPath(ovalIn: NSRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2))
}

func arc(center: CGPoint, radius: CGFloat, start: CGFloat, end: CGFloat) -> NSBezierPath {
    let path = NSBezierPath()
    path.appendArc(withCenter: center, radius: radius, startAngle: start, endAngle: end, clockwise: false)
    return path
}

func drawArc(center: CGPoint, radius: CGFloat, start: CGFloat, end: CGFloat, width: CGFloat, alpha: CGFloat) {
    let glow = arc(center: center, radius: radius, start: start, end: end)
    color(0x46dcff, alpha: alpha * 0.20).setStroke()
    glow.lineCapStyle = .round
    glow.lineWidth = width * 4
    glow.stroke()

    let line = arc(center: center, radius: radius, start: start, end: end)
    color(0x52e2ff, alpha: alpha).setStroke()
    line.lineCapStyle = .round
    line.lineWidth = width
    line.stroke()
}

func drawIcon(size: CGFloat) -> NSImage {
    let image = NSImage(size: NSSize(width: size, height: size))
    image.lockFocus()

    let rect = NSRect(x: 0, y: 0, width: size, height: size)
    color(0x04101a).setFill()
    rect.fill()

    let bg = NSGradient(colors: [
        color(0x122943),
        color(0x071826),
        color(0x020912)
    ])!
    bg.draw(in: rect, angle: -38)

    let center = CGPoint(x: size * 0.50, y: size * 0.53)

    color(0x153b5a, alpha: 0.72).setFill()
    circle(center: center, radius: size * 0.31).fill()

    color(0x06121f, alpha: 0.88).setFill()
    circle(center: center, radius: size * 0.215).fill()

    drawArc(center: center, radius: size * 0.37, start: 18, end: 167, width: max(2, size * 0.013), alpha: 0.96)
    drawArc(center: center, radius: size * 0.37, start: 202, end: 333, width: max(2, size * 0.013), alpha: 0.76)
    drawArc(center: center, radius: size * 0.25, start: 32, end: 306, width: max(1.2, size * 0.0048), alpha: 0.38)

    let nodePositions = [
        CGPoint(x: size * 0.22, y: size * 0.68),
        CGPoint(x: size * 0.78, y: size * 0.70),
        CGPoint(x: size * 0.73, y: size * 0.22),
    ]
    for point in nodePositions {
        color(0x071827, alpha: 0.95).setFill()
        circle(center: point, radius: size * 0.035).fill()
        color(0xa8f2ff, alpha: 0.92).setStroke()
        let path = circle(center: point, radius: size * 0.035)
        path.lineWidth = max(1, size * 0.006)
        path.stroke()
    }

    let line = NSBezierPath()
    line.move(to: CGPoint(x: size * 0.30, y: size * 0.66))
    line.curve(to: CGPoint(x: size * 0.70, y: size * 0.25), controlPoint1: CGPoint(x: size * 0.48, y: size * 0.78), controlPoint2: CGPoint(x: size * 0.76, y: size * 0.49))
    color(0x52e2ff, alpha: 0.24).setStroke()
    line.lineWidth = max(1, size * 0.004)
    line.stroke()

    let title = size < 64 ? "J" : "J"
    let attrs: [NSAttributedString.Key: Any] = [
        .font: NSFont.systemFont(ofSize: size * 0.42, weight: .black),
        .foregroundColor: color(0xf0fbff),
        .kern: 0
    ]
    let text = NSString(string: title)
    let textSize = text.size(withAttributes: attrs)
    text.draw(at: CGPoint(x: (size - textSize.width) / 2, y: size * 0.44 - textSize.height / 2), withAttributes: attrs)

    if size >= 64 {
        let badgeRect = NSRect(x: size * 0.58, y: size * 0.16, width: size * 0.25, height: size * 0.14)
        let badge = NSBezierPath(roundedRect: badgeRect, xRadius: size * 0.035, yRadius: size * 0.035)
        color(0x071827, alpha: 0.96).setFill()
        badge.fill()
        color(0x9af1ff, alpha: 0.9).setStroke()
        badge.lineWidth = max(1, size * 0.006)
        badge.stroke()

        let pcAttrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedSystemFont(ofSize: size * 0.058, weight: .bold),
            .foregroundColor: color(0xdffaff),
            .kern: 0
        ]
        let pc = NSString(string: "PC")
        let pcSize = pc.size(withAttributes: pcAttrs)
        pc.draw(at: CGPoint(x: badgeRect.midX - pcSize.width / 2, y: badgeRect.midY - pcSize.height / 2), withAttributes: pcAttrs)
    }

    color(0xffffff, alpha: 0.09).setFill()
    NSBezierPath(ovalIn: NSRect(x: size * 0.18, y: size * 0.68, width: size * 0.36, height: size * 0.11)).fill()

    image.unlockFocus()
    return image
}

for (name, size) in specs {
    let image = drawIcon(size: size)
    guard let tiff = image.tiffRepresentation,
          let rep = NSBitmapImageRep(data: tiff),
          let png = rep.representation(using: .png, properties: [:]) else {
        fatalError("Could not create \(name)")
    }
    try png.write(to: outputURL.appendingPathComponent(name))
}
