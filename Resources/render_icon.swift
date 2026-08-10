import AppKit

// 1024x1024 app icon: dark rounded-square background (same treatment as
// before) with the user's actual quill artwork (~/Downloads/quill/quill.png
// — a solid black silhouette with alpha, recolored here to sit on the dark
// background) composited on top. Previous versions of this file hand-drew
// a feather from scratch instead of using the provided artwork — this one
// uses the real logo, not an invented substitute.
let size: CGFloat = 1024
let canvas = NSImage(size: NSSize(width: size, height: size))
canvas.lockFocus()

let bgRect = NSRect(x: 0, y: 0, width: size, height: size)
let bgPath = NSBezierPath(roundedRect: bgRect, xRadius: size * 0.225, yRadius: size * 0.225)
NSColor(calibratedRed: 0.075, green: 0.078, blue: 0.086, alpha: 1.0).setFill()
bgPath.fill()
NSGradient(colors: [
    NSColor(calibratedWhite: 1.0, alpha: 0.06),
    NSColor(calibratedWhite: 0.0, alpha: 0.0),
])?.draw(in: bgPath, angle: 90)

let sourcePath = CommandLine.arguments.count > 2
    ? CommandLine.arguments[2]
    : NSString(string: "~/Downloads/quill/quill.png").expandingTildeInPath

guard let sourceImage = NSImage(contentsOfFile: sourcePath) else {
    FileHandle.standardError.write(Data("couldn't load source artwork at \(sourcePath)\n".utf8))
    exit(1)
}

let glyphColor = NSColor(calibratedRed: 0.90, green: 0.93, blue: 0.99, alpha: 1.0)

// Recolor the (black) source artwork to glyphColor. Done in an isolated
// NSImage first, not directly on the canvas — filling a color rect, then
// drawing the source on top with .destinationIn, trims that fill down to
// exactly the source's own alpha shape. (Tried compositing straight onto
// the canvas with .sourceAtop first — masked the whole opaque background
// instead of just the glyph, since sourceAtop reads the *entire* current
// context's alpha, not just what was most recently drawn.)
let tinted = NSImage(size: sourceImage.size)
tinted.lockFocus()
glyphColor.setFill()
NSRect(origin: .zero, size: sourceImage.size).fill()
sourceImage.draw(
    in: NSRect(origin: .zero, size: sourceImage.size),
    from: .zero,
    operation: .destinationIn,
    fraction: 1.0
)
tinted.unlockFocus()

let margin: CGFloat = size * 0.20
let artRect = NSRect(x: margin, y: margin, width: size - margin * 2, height: size - margin * 2)
tinted.draw(
    in: artRect,
    from: NSRect(origin: .zero, size: tinted.size),
    operation: .sourceOver,
    fraction: 1.0
)

canvas.unlockFocus()

guard let tiff = canvas.tiffRepresentation,
      let rep = NSBitmapImageRep(data: tiff),
      let png = rep.representation(using: .png, properties: [:])
else {
    FileHandle.standardError.write(Data("failed to render PNG\n".utf8))
    exit(1)
}

let outPath = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "icon_1024.png"
try png.write(to: URL(fileURLWithPath: outPath))
print("wrote \(outPath)")
