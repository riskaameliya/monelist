import AppKit

guard CommandLine.arguments.count == 3 else {
    fatalError("Usage: create-app-icon.swift <logo.png> <output.png>")
}

guard let logo = NSImage(contentsOfFile: CommandLine.arguments[1]) else {
    fatalError("Could not load logo image at \(CommandLine.arguments[1])")
}

let dimension = 1024
let bitmap = NSBitmapImageRep(
    bitmapDataPlanes: nil,
    pixelsWide: dimension,
    pixelsHigh: dimension,
    bitsPerSample: 8,
    samplesPerPixel: 4,
    hasAlpha: true,
    isPlanar: false,
    colorSpaceName: .deviceRGB,
    bytesPerRow: 0,
    bitsPerPixel: 0
)!

NSGraphicsContext.saveGraphicsState()
let graphics = NSGraphicsContext(bitmapImageRep: bitmap)!
NSGraphicsContext.current = graphics
graphics.imageInterpolation = .high
graphics.cgContext.setShouldAntialias(true)

NSColor.clear.setFill()
NSRect(x: 0, y: 0, width: dimension, height: dimension).fill()

let background = NSBezierPath(
    roundedRect: NSRect(x: 24, y: 24, width: 976, height: 976),
    xRadius: 230,
    yRadius: 230
)
NSColor(red: 0.13, green: 0.17, blue: 0.19, alpha: 1).setFill()
background.fill()

let scale = min(920 / logo.size.width, 940 / logo.size.height)
let logoSize = NSSize(width: logo.size.width * scale, height: logo.size.height * scale)
let logoRect = NSRect(
    x: (CGFloat(dimension) - logoSize.width) / 2,
    y: (CGFloat(dimension) - logoSize.height) / 2,
    width: logoSize.width,
    height: logoSize.height
)
logo.draw(
    in: logoRect,
    from: NSRect(origin: .zero, size: logo.size),
    operation: .sourceOver,
    fraction: 1
)

NSGraphicsContext.restoreGraphicsState()

guard let png = bitmap.representation(using: .png, properties: [:]) else {
    fatalError("Could not encode app icon as PNG")
}
try png.write(to: URL(fileURLWithPath: CommandLine.arguments[2]))
