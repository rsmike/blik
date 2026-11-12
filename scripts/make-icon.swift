// Draws Blik's app icon and writes every size the asset catalog needs.
//
//   swift scripts/make-icon.swift
//
// The icon is the eye from the reminders, white on the black of the notch drop, on the
// standard macOS rounded square. Change the numbers below and run it again to restyle it.

import AppKit

let canvas: CGFloat = 1024
/// The standard macOS icon grid: an 824 pt rounded square centred on a 1024 pt canvas.
let tile = CGRect(x: 100, y: 100, width: 824, height: 824)
let tileRadius: CGFloat = 185

let eyeWidth: CGFloat = 540
let eyeHeight: CGFloat = eyeWidth * 0.58
let eyeLine: CGFloat = 36
let irisSize: CGFloat = eyeHeight * 0.56

func draw(in context: CGContext) {
    let space = CGColorSpace(name: CGColorSpace.sRGB)!

    // The tile, with the soft shadow macOS icons sit on.
    let tilePath = CGPath(roundedRect: tile, cornerWidth: tileRadius, cornerHeight: tileRadius, transform: nil)
    context.saveGState()
    context.setShadow(offset: CGSize(width: 0, height: -12), blur: 28, color: CGColor(gray: 0, alpha: 0.35))
    context.addPath(tilePath)
    context.setFillColor(CGColor(gray: 0.05, alpha: 1))
    context.fillPath()
    context.restoreGState()

    // A dark gradient, a little lighter at the top.
    context.saveGState()
    context.addPath(tilePath)
    context.clip()
    let colours = [CGColor(srgbRed: 0.23, green: 0.23, blue: 0.26, alpha: 1), CGColor(srgbRed: 0.04, green: 0.04, blue: 0.05, alpha: 1)]
    let gradient = CGGradient(colorsSpace: space, colors: colours as CFArray, locations: [0, 1])!
    context.drawLinearGradient(gradient, start: CGPoint(x: 0, y: tile.maxY), end: CGPoint(x: 0, y: tile.minY), options: [])
    context.restoreGState()

    // The eye: two curves meeting at the corners, and the iris between them.
    let centre = CGPoint(x: canvas / 2, y: canvas / 2)
    let left = CGPoint(x: centre.x - eyeWidth / 2, y: centre.y)
    let right = CGPoint(x: centre.x + eyeWidth / 2, y: centre.y)
    let eye = CGMutablePath()
    eye.move(to: left)
    eye.addQuadCurve(to: right, control: CGPoint(x: centre.x, y: centre.y + eyeHeight))
    eye.addQuadCurve(to: left, control: CGPoint(x: centre.x, y: centre.y - eyeHeight))
    eye.closeSubpath()

    context.setStrokeColor(CGColor(gray: 1, alpha: 1))
    context.setFillColor(CGColor(gray: 1, alpha: 1))
    context.setLineWidth(eyeLine)
    context.setLineJoin(.round)
    context.setLineCap(.round)
    context.addPath(eye)
    context.strokePath()
    context.fillEllipse(in: CGRect(x: centre.x - irisSize / 2, y: centre.y - irisSize / 2, width: irisSize, height: irisSize))
}

/// The icon at `pixels` square.
func render(_ pixels: Int) -> Data {
    let bitmap = NSBitmapImageRep(
        bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels, bitsPerSample: 8, samplesPerPixel: 4,
        hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
    )!
    let graphics = NSGraphicsContext(bitmapImageRep: bitmap)!
    let context = graphics.cgContext
    context.interpolationQuality = .high
    context.scaleBy(x: CGFloat(pixels) / canvas, y: CGFloat(pixels) / canvas)
    draw(in: context)
    return bitmap.representation(using: .png, properties: [:])!
}

// Size in points and scale, as the asset catalog lists them.
let slots: [(points: Int, scale: Int)] = [
    (16, 1), (16, 2), (32, 1), (32, 2), (128, 1), (128, 2), (256, 1), (256, 2), (512, 1), (512, 2)
]

let root = URL(fileURLWithPath: CommandLine.arguments[0]).deletingLastPathComponent().deletingLastPathComponent()
let folder = root.appendingPathComponent("Blik/Assets.xcassets/AppIcon.appiconset")
try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)

var images: [[String: String]] = []
for slot in slots {
    let name = slot.scale == 1 ? "icon_\(slot.points).png" : "icon_\(slot.points)@2x.png"
    try render(slot.points * slot.scale).write(to: folder.appendingPathComponent(name))
    images.append([
        "filename": name,
        "idiom": "mac",
        "scale": "\(slot.scale)x",
        "size": "\(slot.points)x\(slot.points)"
    ])
}

let contents: [String: Any] = ["images": images, "info": ["author": "xcode", "version": 1]]
let json = try JSONSerialization.data(withJSONObject: contents, options: [.prettyPrinted, .sortedKeys])
try json.write(to: folder.appendingPathComponent("Contents.json"))

let catalog: [String: Any] = ["info": ["author": "xcode", "version": 1]]
try JSONSerialization.data(withJSONObject: catalog, options: [.prettyPrinted, .sortedKeys])
    .write(to: folder.deletingLastPathComponent().appendingPathComponent("Contents.json"))

print("Wrote \(slots.count) images to \(folder.path)")
