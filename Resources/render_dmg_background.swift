import AppKit

// DMG installer background: dark canvas matching Quill's own theme (not
// Wispr's cream/serif look — same "drag to Applications" convention,
// original composition), sized to match the Finder window bounds set for
// the .dmg (660x400 points) so icon placement lines up exactly.
let width: CGFloat = 660
let height: CGFloat = 400
let canvas = NSImage(size: NSSize(width: width, height: height))
canvas.lockFocus()

NSColor(calibratedRed: 0.075, green: 0.078, blue: 0.086, alpha: 1.0).setFill()
NSRect(x: 0, y: 0, width: width, height: height).fill()

// Subtle top-down vignette, same treatment as the app icon background.
NSGradient(colors: [
    NSColor(calibratedWhite: 1.0, alpha: 0.04),
    NSColor(calibratedWhite: 0.0, alpha: 0.0),
])?.draw(in: NSRect(x: 0, y: 0, width: width, height: height), angle: 90)

let accent = NSColor(calibratedRed: 181 / 255, green: 209 / 255, blue: 255 / 255, alpha: 1.0)

// Headline.
let title = "To install, drag Quill to Applications"
let titleStyle = NSMutableParagraphStyle()
titleStyle.alignment = .center
let titleAttrs: [NSAttributedString.Key: Any] = [
    .font: NSFont.systemFont(ofSize: 20, weight: .semibold),
    .foregroundColor: NSColor.white,
    .paragraphStyle: titleStyle,
]
(title as NSString).draw(
    in: NSRect(x: 0, y: height - 80, width: width, height: 30),
    withAttributes: titleAttrs
)

let subtitle = "Everything runs locally on this Mac — nothing is uploaded."
let subtitleAttrs: [NSAttributedString.Key: Any] = [
    .font: NSFont.systemFont(ofSize: 12, weight: .regular),
    .foregroundColor: NSColor.white.withAlphaComponent(0.45),
    .paragraphStyle: titleStyle,
]
(subtitle as NSString).draw(
    in: NSRect(x: 0, y: height - 102, width: width, height: 18),
    withAttributes: subtitleAttrs
)

// Curved connecting arrow between the two icon slots (icons placed via
// Finder AppleScript at 180,190 and 480,190 in Finder's bottom-left-origin
// coordinate space — that's y=210 from the top here, roughly icon-center
// height).
let arrowY = height - 210
let arrow = NSBezierPath()
arrow.move(to: NSPoint(x: 250, y: arrowY + 10))
arrow.curve(
    to: NSPoint(x: 410, y: arrowY + 10),
    controlPoint1: NSPoint(x: 300, y: arrowY + 55),
    controlPoint2: NSPoint(x: 360, y: arrowY + 55)
)
arrow.lineWidth = 2.5
accent.withAlphaComponent(0.55).setStroke()
arrow.stroke()

// Arrowhead.
let headSize: CGFloat = 8
let head = NSBezierPath()
head.move(to: NSPoint(x: 410 - headSize, y: arrowY + 10 + headSize * 0.6))
head.line(to: NSPoint(x: 410, y: arrowY + 10))
head.line(to: NSPoint(x: 410 - headSize * 0.6, y: arrowY + 10 - headSize))
head.lineWidth = 2.5
head.lineCapStyle = .round
head.lineJoinStyle = .round
accent.withAlphaComponent(0.55).setStroke()
head.stroke()

canvas.unlockFocus()

guard let tiff = canvas.tiffRepresentation,
      let rep = NSBitmapImageRep(data: tiff),
      let png = rep.representation(using: .png, properties: [:])
else {
    FileHandle.standardError.write(Data("failed to render PNG\n".utf8))
    exit(1)
}

let outPath = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "dmg_background.png"
try png.write(to: URL(fileURLWithPath: outPath))
print("wrote \(outPath)")
