// Draws the Mickey app icon from scratch and writes App/Resources/Assets.xcassets/AppIcon.appiconset.
// Usage: swift scripts/make_app_icon.swift [output-appiconset-dir]
import AppKit

let out = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "App/Resources/Assets.xcassets/AppIcon.appiconset"
let sizes: [(points: Int, scale: Int)] = [(16, 1), (16, 2), (32, 1), (32, 2), (128, 1), (128, 2), (256, 1), (256, 2), (512, 1), (512, 2)]

func render(pixels: Int) -> Data {
    let s = CGFloat(pixels)
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels, bitsPerSample: 8,
                               samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB,
                               bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    let ctx = NSGraphicsContext.current!.cgContext

    // Rounded-square background with a dark indigo gradient (macOS icon grid: 10% inset).
    let inset = s * 0.1
    let tile = CGRect(x: inset, y: inset, width: s - 2 * inset, height: s - 2 * inset)
    let tilePath = CGPath(roundedRect: tile, cornerWidth: tile.width * 0.225, cornerHeight: tile.width * 0.225, transform: nil)
    ctx.addPath(tilePath)
    ctx.clip()
    let colors = [CGColor(srgbRed: 0.16, green: 0.13, blue: 0.36, alpha: 1), CGColor(srgbRed: 0.05, green: 0.05, blue: 0.12, alpha: 1)]
    let gradient = CGGradient(colorsSpace: CGColorSpace(name: CGColorSpace.sRGB), colors: colors as CFArray, locations: [0, 1])!
    ctx.drawLinearGradient(gradient, start: CGPoint(x: 0, y: s), end: CGPoint(x: 0, y: 0), options: [])

    // Spotlight glow.
    let center = CGPoint(x: s * 0.46, y: s * 0.54)
    let glow = CGGradient(colorsSpace: CGColorSpace(name: CGColorSpace.sRGB),
                          colors: [CGColor(srgbRed: 1, green: 0.85, blue: 0.35, alpha: 0.55), CGColor(srgbRed: 1, green: 0.85, blue: 0.35, alpha: 0)] as CFArray,
                          locations: [0, 1])!
    ctx.drawRadialGradient(glow, startCenter: center, startRadius: 0, endCenter: center, endRadius: s * 0.3, options: [])

    // Ring.
    ctx.setStrokeColor(CGColor(srgbRed: 1, green: 0.85, blue: 0.35, alpha: 1))
    ctx.setLineWidth(s * 0.035)
    ctx.strokeEllipse(in: CGRect(x: center.x - s * 0.19, y: center.y - s * 0.19, width: s * 0.38, height: s * 0.38))

    // Arrow pointer with its tip at the ring centre.
    let u = s * 0.0125
    let tip = center
    let arrow = CGMutablePath()
    let pts: [(CGFloat, CGFloat)] = [(0, 0), (0, -22), (5.5, -17), (9.5, -26), (13, -24.5), (9, -15.5), (16, -15.5)]
    arrow.move(to: CGPoint(x: tip.x + pts[0].0 * u, y: tip.y + pts[0].1 * u))
    for p in pts.dropFirst() { arrow.addLine(to: CGPoint(x: tip.x + p.0 * u, y: tip.y + p.1 * u)) }
    arrow.closeSubpath()
    ctx.addPath(arrow)
    ctx.setFillColor(CGColor(gray: 1, alpha: 1))
    ctx.setStrokeColor(CGColor(gray: 0, alpha: 1))
    ctx.setLineWidth(max(1, u * 1.4))
    ctx.setLineJoin(.round)
    ctx.drawPath(using: .fillStroke)

    NSGraphicsContext.restoreGraphicsState()
    return rep.representation(using: .png, properties: [:])!
}

try FileManager.default.createDirectory(atPath: out, withIntermediateDirectories: true)
var images: [[String: String]] = []
for (points, scale) in sizes {
    let name = "icon_\(points)x\(points)\(scale == 2 ? "@2x" : "").png"
    try render(pixels: points * scale).write(to: URL(fileURLWithPath: out).appendingPathComponent(name))
    images.append(["idiom": "mac", "size": "\(points)x\(points)", "scale": "\(scale)x", "filename": name])
}
let contents: [String: Any] = ["images": images, "info": ["author": "xcode", "version": 1]]
try JSONSerialization.data(withJSONObject: contents, options: [.prettyPrinted, .sortedKeys])
    .write(to: URL(fileURLWithPath: out).appendingPathComponent("Contents.json"))
let catalog = URL(fileURLWithPath: out).deletingLastPathComponent().appendingPathComponent("Contents.json")
try #"{ "info" : { "author" : "xcode", "version" : 1 } }"#.write(to: catalog, atomically: true, encoding: .utf8)
print("Wrote \(sizes.count) icons to \(out)")
