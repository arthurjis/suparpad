#!/usr/bin/env swift
// Generates the suparpad app icon: a 3x3 grid of white tiles (matching the
// menu bar glyph) on a dark gradient squircle, Big Sur+ shape with margins.
// Writes an .iconset and compiles it to resources/AppIcon.icns via iconutil.
//
// Usage: swift scripts/make-icon.swift   (run from the repo root)

import AppKit

// Design is authored on a 1024pt canvas; everything scales by f = size/1024.
func draw(canvas: CGFloat) -> NSBitmapImageRep {
    let px = Int(canvas)
    let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil, pixelsWide: px, pixelsHigh: px,
        bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
        colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
    )!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    let f = canvas / 1024.0

    // Squircle plate: 824x824 centered (Apple's icon grid), radius 185.
    let plate = NSBezierPath(
        roundedRect: NSRect(x: 100 * f, y: 100 * f, width: 824 * f, height: 824 * f),
        xRadius: 185 * f, yRadius: 185 * f
    )
    NSGradient(
        starting: NSColor(calibratedRed: 0.42, green: 0.46, blue: 0.72, alpha: 1),
        ending: NSColor(calibratedRed: 0.13, green: 0.14, blue: 0.25, alpha: 1)
    )!.draw(in: plate, angle: -90)

    // 3x3 grid of tiles, 480pt block centered: tile 144, gap 24.
    let tile: CGFloat = 144, gap: CGFloat = 24
    let block = 3 * tile + 2 * gap
    let origin = (1024 - block) / 2
    let shadow = NSShadow()
    shadow.shadowColor = NSColor.black.withAlphaComponent(0.30)
    shadow.shadowBlurRadius = 14 * f
    shadow.shadowOffset = NSSize(width: 0, height: -5 * f)
    shadow.set()
    NSColor(calibratedWhite: 1.0, alpha: 0.96).setFill()
    for row in 0..<3 {
        for col in 0..<3 {
            let x = origin + CGFloat(col) * (tile + gap)
            let y = origin + CGFloat(row) * (tile + gap)
            NSBezierPath(
                roundedRect: NSRect(x: x * f, y: y * f, width: tile * f, height: tile * f),
                xRadius: 34 * f, yRadius: 34 * f
            ).fill()
        }
    }

    NSGraphicsContext.restoreGraphicsState()
    return rep
}

let iconset = "resources/AppIcon.iconset"
try? FileManager.default.removeItem(atPath: iconset)
try! FileManager.default.createDirectory(atPath: iconset, withIntermediateDirectories: true)

let entries: [(String, CGFloat)] = [
    ("icon_16x16", 16), ("icon_16x16@2x", 32),
    ("icon_32x32", 32), ("icon_32x32@2x", 64),
    ("icon_128x128", 128), ("icon_128x128@2x", 256),
    ("icon_256x256", 256), ("icon_256x256@2x", 512),
    ("icon_512x512", 512), ("icon_512x512@2x", 1024),
]
for (name, size) in entries {
    let png = draw(canvas: size).representation(using: .png, properties: [:])!
    try! png.write(to: URL(fileURLWithPath: "\(iconset)/\(name).png"))
}

let task = Process()
task.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
task.arguments = ["-c", "icns", iconset, "-o", "resources/AppIcon.icns"]
try! task.run()
task.waitUntilExit()
print(task.terminationStatus == 0 ? "wrote resources/AppIcon.icns" : "iconutil FAILED")
