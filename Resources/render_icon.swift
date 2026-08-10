import AppKit

// 1024x1024 app icon: dark rounded-square background, solid feather
// silhouette with jagged barb edges + a quill nib + ink flourish, inspired
// by the classic "quill pen" icon motif (own construction, not traced).
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

// --- Feather silhouette, built vertically in local space (tip up, nib down) ---
// A jagged edge is built from alternating outward "barb" points and inward
// notches down each side, narrowing to a point at the top and a thin nib
// at the bottom.
func point(_ x: CGFloat, _ y: CGFloat) -> NSPoint { NSPoint(x: x, y: y) }

let feather = NSBezierPath()
feather.move(to: point(0, 210))   // tip

// Right side, tip -> base: alternating out/in barb notches.
let rightBarbs: [(CGFloat, CGFloat)] = [
    (34, 172), (18, 158), (46, 128), (24, 112),
    (52, 82), (28, 64), (54, 34), (26, 16),
    (50, -16), (24, -34), (40, -64), (18, -82),
    (28, -112), (10, -128),
]
for (x, y) in rightBarbs { feather.line(to: point(x, y)) }
feather.line(to: point(6, -160))   // narrowing toward the nib
feather.line(to: point(0, -215))   // nib point

// Left side, base -> tip (mirror, offset for a slightly narrower back edge).
let leftBarbs: [(CGFloat, CGFloat)] = [
    (-5, -160), (-9, -128), (-24, -112), (-16, -82),
    (-36, -64), (-22, -34), (-44, -16), (-24, 16),
    (-46, 34), (-24, 64), (-46, 82), (-20, 112),
    (-40, 128), (-16, 158), (-30, 172),
]
for (x, y) in leftBarbs { feather.line(to: point(x, y)) }
feather.close()

// Center spine.
let spine = NSBezierPath()
spine.move(to: point(0, -215))
spine.line(to: point(0, 205))
spine.lineWidth = 6
spine.lineCapStyle = .round

// Ink flourish swash trailing from the nib.
let flourish = NSBezierPath()
flourish.move(to: point(2, -213))
flourish.curve(
    to: point(230, -250),
    controlPoint1: point(60, -260),
    controlPoint2: point(140, -270)
)
flourish.lineWidth = 9
flourish.lineCapStyle = .round

// Rotate + scale + center the whole composition.
let t = NSAffineTransform()
t.rotate(byDegrees: -18)
t.scale(by: 1.5)

func placed(_ p: NSBezierPath) -> NSBezierPath { t.transform(p) }

let featherP = placed(feather)
let spineP = placed(spine)
let flourishP = placed(flourish)

// Compute combined bounds (feather + flourish) to center on canvas.
var bounds = featherP.bounds
bounds = bounds.union(flourishP.bounds)
let centerT = NSAffineTransform()
centerT.translateX(by: size / 2 - bounds.midX, yBy: size / 2 - bounds.midY + size * 0.02)

func final(_ p: NSBezierPath) -> NSBezierPath { centerT.transform(p) }

let featherFinal = final(featherP)
let spineFinal = final(spineP)
let flourishFinal = final(flourishP)

let glyphColor = NSColor(calibratedRed: 0.90, green: 0.93, blue: 0.99, alpha: 1.0)
let spineColor = NSColor(calibratedRed: 0.075, green: 0.078, blue: 0.086, alpha: 0.55)

glyphColor.setFill()
featherFinal.fill()

spineColor.setStroke()
spineFinal.lineWidth = 6
spineFinal.stroke()

glyphColor.setStroke()
flourishFinal.lineWidth = 9
flourishFinal.stroke()

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
