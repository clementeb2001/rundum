import AppKit
import Foundation

// Original, code-drawn app icon. No external assets or font dependencies.
let directory = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "App/Resources/Assets.xcassets/AppIcon.appiconset"
try FileManager.default.createDirectory(atPath: directory, withIntermediateDirectories: true)
let size = NSSize(width: 1024, height: 1024)
let image = NSImage(size: size)
image.lockFocus()
NSColor(calibratedRed: 0.12, green: 0.40, blue: 0.36, alpha: 1).setFill()
NSBezierPath(rect: NSRect(origin: .zero, size: size)).fill()
let centers = [NSPoint(x: 380, y: 640), NSPoint(x: 644, y: 640), NSPoint(x: 380, y: 376), NSPoint(x: 644, y: 376)]
for (i, center) in centers.enumerated() {
    let path = NSBezierPath(ovalIn: NSRect(x: center.x - 104, y: center.y - 104, width: 208, height: 208))
    if i == 1 { NSColor(calibratedRed: 0.98, green: 0.85, blue: 0.74, alpha: 1).setFill(); path.fill() }
    else { NSColor.white.setStroke(); path.lineWidth = 34; path.stroke() }
}
image.unlockFocus()
let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: 1024, pixelsHigh: 1024, bitsPerSample: 8, samplesPerPixel: 3, hasAlpha: false, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
image.draw(in: NSRect(origin: .zero, size: size))
NSGraphicsContext.restoreGraphicsState()
try bitmap.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: directory).appendingPathComponent("AppIcon.png"))
