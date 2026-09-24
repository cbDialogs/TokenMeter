#!/usr/bin/env swift
// Draws the TokenMeter app icon and writes Resources/AppIcon.icns.
// Usage: swift scripts/make-icon.swift
import AppKit

let size: CGFloat = 1024

func drawIcon(in ctx: CGContext) {
    let full = CGRect(x: 0, y: 0, width: size, height: size)

    // macOS icon grid: 824pt squircle-ish tile centered on a 1024 canvas.
    let tile = full.insetBy(dx: 100, dy: 100)
    let tilePath = CGPath(roundedRect: tile, cornerWidth: 185, cornerHeight: 185, transform: nil)

    // Drop shadow under the tile.
    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -12), blur: 28, color: NSColor.black.withAlphaComponent(0.35).cgColor)
    ctx.addPath(tilePath)
    ctx.setFillColor(NSColor.black.cgColor)
    ctx.fillPath()
    ctx.restoreGState()

    // Dark gradient tile.
    ctx.saveGState()
    ctx.addPath(tilePath)
    ctx.clip()
    let bg = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: [
        NSColor(red: 0.20, green: 0.21, blue: 0.24, alpha: 1).cgColor,
        NSColor(red: 0.07, green: 0.07, blue: 0.09, alpha: 1).cgColor,
    ] as CFArray, locations: [0, 1])!
    ctx.drawLinearGradient(bg, start: CGPoint(x: 0, y: tile.maxY), end: CGPoint(x: 0, y: tile.minY), options: [])
    ctx.restoreGState()

    let center = CGPoint(x: size / 2, y: size / 2 - 80)
    let radius: CGFloat = 330

    // Gauge sweeps 240°, from lower-left (210°) clockwise to lower-right (-30°).
    // Core Graphics angles are counter-clockwise from +x with y up.
    func angle(_ value: CGFloat) -> CGFloat { (210 - 240 * value / 100) * .pi / 180 }
    func point(_ r: CGFloat, _ a: CGFloat) -> CGPoint { CGPoint(x: center.x + r * cos(a), y: center.y + r * sin(a)) }

    // Colored zones: green → amber → red.
    let zones: [(CGFloat, CGFloat, NSColor)] = [
        (0, 62, NSColor(red: 0.22, green: 0.78, blue: 0.40, alpha: 1)),
        (62, 80, NSColor(red: 0.98, green: 0.74, blue: 0.16, alpha: 1)),
        (80, 100, NSColor(red: 0.93, green: 0.27, blue: 0.22, alpha: 1)),
    ]
    ctx.setLineWidth(58)
    ctx.setLineCap(.butt)
    for (from, to, color) in zones {
        ctx.addArc(center: center, radius: radius, startAngle: angle(from), endAngle: angle(to), clockwise: true)
        ctx.setStrokeColor(color.cgColor)
        ctx.strokePath()
    }

    // Major ticks.
    ctx.setStrokeColor(NSColor(white: 0.92, alpha: 1).cgColor)
    ctx.setLineCap(.round)
    for v in stride(from: 0, through: 100, by: 10) {
        let a = angle(CGFloat(v))
        let major = v % 20 == 0
        ctx.setLineWidth(major ? 16 : 9)
        ctx.move(to: point(radius - 60, a))
        ctx.addLine(to: point(radius - (major ? 120 : 95), a))
        ctx.strokePath()
    }

    // Pace marker: white triangle on the rim at ~62%.
    let pa = angle(62)
    let tip = point(radius - 50, pa)
    let base = point(radius + 60, pa)
    let perp = pa + .pi / 2
    ctx.move(to: tip)
    ctx.addLine(to: CGPoint(x: base.x + 34 * cos(perp), y: base.y + 34 * sin(perp)))
    ctx.addLine(to: CGPoint(x: base.x - 34 * cos(perp), y: base.y - 34 * sin(perp)))
    ctx.closePath()
    ctx.setFillColor(NSColor.white.cgColor)
    ctx.fillPath()

    // Needle at ~48%, tapered.
    let na = angle(48)
    let needleTip = point(radius - 40, na)
    let tail = point(-60, na)
    let np = na + .pi / 2
    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -6), blur: 14, color: NSColor.black.withAlphaComponent(0.5).cgColor)
    ctx.move(to: needleTip)
    ctx.addLine(to: CGPoint(x: tail.x + 26 * cos(np), y: tail.y + 26 * sin(np)))
    ctx.addLine(to: CGPoint(x: tail.x - 26 * cos(np), y: tail.y - 26 * sin(np)))
    ctx.closePath()
    ctx.setFillColor(NSColor(red: 0.96, green: 0.30, blue: 0.24, alpha: 1).cgColor)
    ctx.fillPath()
    ctx.restoreGState()

    // Hub.
    ctx.setFillColor(NSColor(white: 0.95, alpha: 1).cgColor)
    ctx.fillEllipse(in: CGRect(x: center.x - 52, y: center.y - 52, width: 104, height: 104))
    ctx.setFillColor(NSColor(white: 0.25, alpha: 1).cgColor)
    ctx.fillEllipse(in: CGRect(x: center.x - 18, y: center.y - 18, width: 36, height: 36))
}

func png(pixels: Int) -> Data {
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels,
                               bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                               colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    let gctx = NSGraphicsContext(bitmapImageRep: rep)!
    let ctx = gctx.cgContext
    ctx.scaleBy(x: CGFloat(pixels) / size, y: CGFloat(pixels) / size)
    ctx.interpolationQuality = .high
    ctx.setShouldAntialias(true)
    drawIcon(in: ctx)
    return rep.representation(using: .png, properties: [:])!
}

let root = URL(fileURLWithPath: CommandLine.arguments[0]).deletingLastPathComponent().deletingLastPathComponent()
let iconset = FileManager.default.temporaryDirectory.appendingPathComponent("AppIcon.iconset")
try? FileManager.default.removeItem(at: iconset)
try FileManager.default.createDirectory(at: iconset, withIntermediateDirectories: true)

for base in [16, 32, 128, 256, 512] {
    try png(pixels: base).write(to: iconset.appendingPathComponent("icon_\(base)x\(base).png"))
    try png(pixels: base * 2).write(to: iconset.appendingPathComponent("icon_\(base)x\(base)@2x.png"))
}
try png(pixels: 1024).write(to: root.appendingPathComponent("docs/icon.png"))

let iconutil = Process()
iconutil.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
iconutil.arguments = ["-c", "icns", iconset.path, "-o", root.appendingPathComponent("Resources/AppIcon.icns").path]
try iconutil.run()
iconutil.waitUntilExit()
print(iconutil.terminationStatus == 0 ? "Wrote Resources/AppIcon.icns and docs/icon.png" : "iconutil failed")
