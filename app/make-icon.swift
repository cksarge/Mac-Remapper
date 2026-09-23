#!/usr/bin/env swift
// Generates Resources/AppIcon.icns: a blue rounded-square app icon with a white keycap
// bearing a swap arrow. Run from app/: `swift make-icon.swift`
import AppKit

let brandBlue = NSColor(srgbRed: 0x34 / 255, green: 0x57 / 255, blue: 0xD5 / 255, alpha: 1)
let lightBlue = NSColor(srgbRed: 0x5B / 255, green: 0x8C / 255, blue: 0xF5 / 255, alpha: 1)
let deepBlue = NSColor(srgbRed: 0x22 / 255, green: 0x3A / 255, blue: 0xA8 / 255, alpha: 1)

/// Draws the icon on a 1024-point canvas, following Apple's macOS icon grid (824pt body, 100pt margins).
func drawIcon(in ctx: CGContext) {
    // Body with drop shadow
    let body = CGRect(x: 100, y: 100, width: 824, height: 824)
    let bodyPath = CGPath(roundedRect: body, cornerWidth: 185, cornerHeight: 185, transform: nil)
    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -12), blur: 28, color: NSColor.black.withAlphaComponent(0.35).cgColor)
    ctx.addPath(bodyPath)
    ctx.setFillColor(brandBlue.cgColor)
    ctx.fillPath()
    ctx.restoreGState()

    ctx.saveGState()
    ctx.addPath(bodyPath)
    ctx.clip()
    let bg = CGGradient(colorsSpace: CGColorSpace(name: CGColorSpace.sRGB),
                        colors: [lightBlue.cgColor, brandBlue.cgColor, deepBlue.cgColor] as CFArray,
                        locations: [0, 0.5, 1])!
    ctx.drawLinearGradient(bg, start: CGPoint(x: 512, y: 924), end: CGPoint(x: 512, y: 100), options: [])
    ctx.restoreGState()

    // Keycap: darker base (key side) plus a lighter top face
    let capBase = CGRect(x: 262, y: 236, width: 500, height: 520)
    let capTop = CGRect(x: 292, y: 296, width: 440, height: 430)
    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -18), blur: 36, color: NSColor.black.withAlphaComponent(0.3).cgColor)
    ctx.addPath(CGPath(roundedRect: capBase, cornerWidth: 96, cornerHeight: 96, transform: nil))
    ctx.setFillColor(NSColor(white: 0.84, alpha: 1).cgColor)
    ctx.fillPath()
    ctx.restoreGState()

    ctx.saveGState()
    ctx.addPath(CGPath(roundedRect: capTop, cornerWidth: 72, cornerHeight: 72, transform: nil))
    ctx.clip()
    let face = CGGradient(colorsSpace: CGColorSpace(name: CGColorSpace.sRGB),
                          colors: [NSColor.white.cgColor, NSColor(white: 0.93, alpha: 1).cgColor] as CFArray,
                          locations: [0, 1])!
    ctx.drawLinearGradient(face, start: CGPoint(x: 512, y: capTop.maxY), end: CGPoint(x: 512, y: capTop.minY), options: [])
    ctx.restoreGState()

    // Swap arrows glyph, centered on the key face
    let config = NSImage.SymbolConfiguration(pointSize: 250, weight: .bold)
        .applying(NSImage.SymbolConfiguration(paletteColors: [brandBlue]))
    if let symbol = NSImage(systemSymbolName: "arrow.left.arrow.right", accessibilityDescription: nil)?
        .withSymbolConfiguration(config) {
        let size = symbol.size
        let rect = CGRect(x: capTop.midX - size.width / 2, y: capTop.midY - size.height / 2,
                          width: size.width, height: size.height)
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(cgContext: ctx, flipped: false)
        symbol.draw(in: rect)
        NSGraphicsContext.restoreGraphicsState()
    }
}

func png(pixels: Int) -> Data {
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels,
                               bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                               colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    let ctx = NSGraphicsContext(bitmapImageRep: rep)!.cgContext
    let scale = CGFloat(pixels) / 1024
    ctx.scaleBy(x: scale, y: scale)
    drawIcon(in: ctx)
    return rep.representation(using: .png, properties: [:])!
}

let fm = FileManager.default
let iconset = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("AppIcon.iconset")
try? fm.removeItem(at: iconset)
try fm.createDirectory(at: iconset, withIntermediateDirectories: true)

for base in [16, 32, 128, 256, 512] {
    try png(pixels: base).write(to: iconset.appendingPathComponent("icon_\(base)x\(base).png"))
    try png(pixels: base * 2).write(to: iconset.appendingPathComponent("icon_\(base)x\(base)@2x.png"))
}
try png(pixels: 1024).write(to: URL(fileURLWithPath: "Resources/AppIcon-1024.png"))

let iconutil = Process()
iconutil.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
iconutil.arguments = ["-c", "icns", iconset.path, "-o", "Resources/AppIcon.icns"]
try iconutil.run()
iconutil.waitUntilExit()
print(iconutil.terminationStatus == 0 ? "Wrote Resources/AppIcon.icns" : "iconutil failed")
