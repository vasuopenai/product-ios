// Renders Food Genie app icon candidates as 1024x1024 PNGs (no alpha, as the App Store requires).
import CoreGraphics
import CoreText
import Foundation
import ImageIO
import UniformTypeIdentifiers

let S: CGFloat = 1024
let outDir = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "."

func rgb(_ hex: UInt32) -> CGColor {
    CGColor(red: CGFloat((hex >> 16) & 0xFF) / 255, green: CGFloat((hex >> 8) & 0xFF) / 255, blue: CGFloat(hex & 0xFF) / 255, alpha: 1)
}
func makeContext() -> CGContext {
    CGContext(data: nil, width: Int(S), height: Int(S), bitsPerComponent: 8, bytesPerRow: 0,
              space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
}
func save(_ ctx: CGContext, _ name: String) {
    let url = URL(fileURLWithPath: outDir).appendingPathComponent(name)
    let dest = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil)!
    CGImageDestinationAddImage(dest, ctx.makeImage()!, nil); CGImageDestinationFinalize(dest)
    print("wrote \(name)")
}
func gradient(_ ctx: CGContext, _ top: UInt32, _ bottom: UInt32) {
    let g = CGGradient(colorsSpace: CGColorSpace(name: CGColorSpace.sRGB)!, colors: [rgb(top), rgb(bottom)] as CFArray, locations: [0, 1])!
    ctx.drawLinearGradient(g, start: CGPoint(x: 0, y: S), end: CGPoint(x: S, y: 0), options: [])
}

/// A leaf in local coordinates: base at (0, -h/2), tip near (0.16w, h/2). The outer side is
/// fuller, the inner side flatter, so it has the lopsided look of a real leaf rather than a lens.
func leafOutline(h: CGFloat, w: CGFloat) -> CGPath {
    let p = CGMutablePath()
    let base = CGPoint(x: 0, y: -h / 2), tip = CGPoint(x: w * 0.16, y: h / 2)
    p.move(to: base)
    p.addCurve(to: tip, control1: CGPoint(x: -w * 1.0, y: -h * 0.12), control2: CGPoint(x: -w * 0.5, y: h * 0.46))
    p.addCurve(to: base, control1: CGPoint(x: w * 0.78, y: h * 0.12), control2: CGPoint(x: w * 0.62, y: -h * 0.34))
    p.closeSubpath()
    return p
}

/// The midrib as a gentle curve from the base toward the tip, used for the vein and as the spine
/// the side veins hang off.
func midribPoint(_ t: CGFloat, h: CGFloat, w: CGFloat) -> CGPoint {
    let a = CGPoint(x: 0, y: -h / 2), c = CGPoint(x: -w * 0.08, y: 0), b = CGPoint(x: w * 0.14, y: h * 0.44)
    let u = 1 - t
    return CGPoint(x: u * u * a.x + 2 * u * t * c.x + t * t * b.x, y: u * u * a.y + 2 * u * t * c.y + t * t * b.y)
}

/// Draws a leaf: filled outline, a stem below the base, and veins (midrib plus side veins) either
/// knocked out to the background or stroked in `veinColor`. `veinsUpTo` limits the midrib (0...1)
/// so a checkmark can take over the upper part.
func drawLeaf(_ ctx: CGContext, center: CGPoint, h: CGFloat, w: CGFloat, rotation: CGFloat, fill: CGColor,
              veinColor: CGColor?, sideVeins: Bool, veinsUpTo: CGFloat = 0.95) {
    ctx.saveGState()
    ctx.translateBy(x: center.x, y: center.y); ctx.rotate(by: rotation)
    ctx.setLineCap(.round); ctx.setLineJoin(.round)

    // Stem: a short tapering curve continuing the midrib below the base.
    ctx.setStrokeColor(fill); ctx.setLineWidth(h * 0.045)
    ctx.move(to: CGPoint(x: 0, y: -h / 2 + h * 0.02))
    ctx.addQuadCurve(to: CGPoint(x: -w * 0.1, y: -h / 2 - h * 0.15), control: CGPoint(x: 0.0, y: -h / 2 - h * 0.08))
    ctx.strokePath()

    ctx.setFillColor(fill); ctx.addPath(leafOutline(h: h, w: w)); ctx.fillPath()

    // Veins.
    if let veinColor { ctx.setStrokeColor(veinColor) } else { ctx.setBlendMode(.clear) }
    ctx.setLineWidth(h * 0.03)
    let steps = 24
    ctx.move(to: midribPoint(0.02, h: h, w: w))
    for i in 1...steps { let t = 0.02 + (veinsUpTo - 0.02) * CGFloat(i) / CGFloat(steps); ctx.addLine(to: midribPoint(t, h: h, w: w)) }
    ctx.strokePath()
    if sideVeins {
        ctx.setLineWidth(h * 0.022)
        for t: CGFloat in [0.22, 0.4, 0.58, 0.74] {
            let o = midribPoint(t, h: h, w: w)
            let len = w * (0.72 - 0.5 * abs(t - 0.4))
            // Veins sweep up and outward, longer toward the middle of the leaf.
            ctx.move(to: o); ctx.addQuadCurve(to: CGPoint(x: o.x - len, y: o.y + len * 0.95), control: CGPoint(x: o.x - len * 0.45, y: o.y + len * 0.3))
            ctx.move(to: o); ctx.addQuadCurve(to: CGPoint(x: o.x + len * 0.8, y: o.y + len * 0.95), control: CGPoint(x: o.x + len * 0.4, y: o.y + len * 0.3))
        }
        ctx.strokePath()
    }
    ctx.restoreGState()
}

func checkPath(size: CGFloat) -> CGPath {
    let p = CGMutablePath()
    p.move(to: CGPoint(x: -size * 0.42, y: 0.02 * size))
    p.addLine(to: CGPoint(x: -size * 0.1, y: -size * 0.28))
    p.addLine(to: CGPoint(x: size * 0.46, y: size * 0.3))
    return p
}
func knockoutCheck(_ ctx: CGContext, at c: CGPoint, size: CGFloat, width: CGFloat) {
    ctx.saveGState(); ctx.translateBy(x: c.x, y: c.y)
    ctx.setLineWidth(width); ctx.setLineCap(.round); ctx.setLineJoin(.round); ctx.setBlendMode(.clear)
    ctx.addPath(checkPath(size: size)); ctx.strokePath(); ctx.restoreGState()
}

// A. White leaf with stem and lower midrib; a checkmark knocked out where the veins would be.
func variantA() {
    let ctx = makeContext()
    gradient(ctx, 0x2FB457, 0x0E7A3A)
    ctx.beginTransparencyLayer(auxiliaryInfo: nil)
    drawLeaf(ctx, center: CGPoint(x: S * 0.51, y: S * 0.53), h: S * 0.70, w: S * 0.40, rotation: -0.45,
             fill: rgb(0xFFFFFF), veinColor: nil, sideVeins: false, veinsUpTo: 0.3)
    knockoutCheck(ctx, at: CGPoint(x: S * 0.52, y: S * 0.55), size: S * 0.28, width: S * 0.06)
    ctx.endTransparencyLayer()
    save(ctx, "A-leaf-check.png")
}

// A2. The same leaf with its full veins and no checkmark.
func variantA2() {
    let ctx = makeContext()
    gradient(ctx, 0x2FB457, 0x0E7A3A)
    ctx.beginTransparencyLayer(auxiliaryInfo: nil)
    drawLeaf(ctx, center: CGPoint(x: S * 0.51, y: S * 0.53), h: S * 0.70, w: S * 0.40, rotation: -0.45,
             fill: rgb(0xFFFFFF), veinColor: nil, sideVeins: true)
    ctx.endTransparencyLayer()
    save(ctx, "A2-leaf-veins.png")
}

// B. A barcode with a veined green leaf growing out of it, on near-black.
func variantB() {
    let ctx = makeContext()
    ctx.setFillColor(rgb(0x0A0A0A)); ctx.fill(CGRect(x: 0, y: 0, width: S, height: S))
    let widths: [CGFloat] = [2, 1, 1, 2, 1, 3, 1, 1, 2, 1, 1, 2, 1, 1, 3, 1, 2, 1, 1, 2]
    let unit = S * 0.0165, gap = unit
    let total = widths.reduce(0) { $0 + $1 * unit } + gap * CGFloat(widths.count - 1)
    var x = (S - total) / 2
    let barBottom = S * 0.22, barTop = S * 0.48
    ctx.setFillColor(rgb(0xF5F5F5))
    for (i, w) in widths.enumerated() {
        let width = w * unit
        let top = (i == 9 || i == 10) ? barTop - S * 0.08 : barTop
        ctx.fill(CGRect(x: x, y: barBottom, width: width, height: top - barBottom)); x += width + gap
    }
    let green = rgb(0x34C759)
    // The leaf's own stem rises out of the gap between the two short bars.
    ctx.setStrokeColor(green); ctx.setLineWidth(S * 0.028); ctx.setLineCap(.round)
    ctx.move(to: CGPoint(x: S * 0.5, y: barTop - S * 0.07))
    ctx.addQuadCurve(to: CGPoint(x: S * 0.515, y: S * 0.56), control: CGPoint(x: S * 0.49, y: S * 0.52)); ctx.strokePath()
    drawLeaf(ctx, center: CGPoint(x: S * 0.56, y: S * 0.72), h: S * 0.40, w: S * 0.23, rotation: -0.5,
             fill: green, veinColor: rgb(0x0A0A0A), sideVeins: true)
    save(ctx, "B-barcode-leaf.png")
}


// C. A veined leaf under a magnifying lens, on a green gradient.
func variantC() {
    let ctx = makeContext()
    gradient(ctx, 0x2FB457, 0x0E7A3A)
    let center = CGPoint(x: S * 0.47, y: S * 0.54), radius = S * 0.28
    ctx.setStrokeColor(rgb(0xFFFFFF)); ctx.setLineWidth(S * 0.065); ctx.setLineCap(.round)
    ctx.addArc(center: center, radius: radius, startAngle: 0, endAngle: .pi * 2, clockwise: false); ctx.strokePath()
    let a: CGFloat = -.pi / 4
    ctx.setLineWidth(S * 0.085)
    ctx.move(to: CGPoint(x: center.x + cos(a) * (radius + S * 0.03), y: center.y + sin(a) * (radius + S * 0.03)))
    ctx.addLine(to: CGPoint(x: center.x + cos(a) * (radius + S * 0.2), y: center.y + sin(a) * (radius + S * 0.2))); ctx.strokePath()
    ctx.beginTransparencyLayer(auxiliaryInfo: nil)
    drawLeaf(ctx, center: CGPoint(x: center.x + S * 0.01, y: center.y + S * 0.03), h: S * 0.36, w: S * 0.21, rotation: -0.5,
             fill: rgb(0xFFFFFF), veinColor: nil, sideVeins: true)
    ctx.endTransparencyLayer()
    save(ctx, "C-leaf-lens.png")
}


/// The lens: ring plus handle toward the bottom right. Returns the ring's center and radius.
@discardableResult
func drawLens(_ ctx: CGContext, color: CGColor) -> (CGPoint, CGFloat) {
    let center = CGPoint(x: S * 0.47, y: S * 0.54), radius = S * 0.28
    ctx.setStrokeColor(color); ctx.setLineWidth(S * 0.065); ctx.setLineCap(.round)
    ctx.addArc(center: center, radius: radius, startAngle: 0, endAngle: .pi * 2, clockwise: false); ctx.strokePath()
    let a: CGFloat = -.pi / 4
    ctx.setLineWidth(S * 0.085)
    ctx.move(to: CGPoint(x: center.x + cos(a) * (radius + S * 0.03), y: center.y + sin(a) * (radius + S * 0.03)))
    ctx.addLine(to: CGPoint(x: center.x + cos(a) * (radius + S * 0.2), y: center.y + sin(a) * (radius + S * 0.2))); ctx.strokePath()
    return (center, radius)
}

// D. A checkmark under the lens: look closely, choose well.
func variantD() {
    let ctx = makeContext()
    gradient(ctx, 0x2FB457, 0x0E7A3A)
    let (c, _) = drawLens(ctx, color: rgb(0xFFFFFF))
    ctx.saveGState(); ctx.translateBy(x: c.x, y: c.y + S * 0.01)
    ctx.setStrokeColor(rgb(0xFFFFFF)); ctx.setLineWidth(S * 0.075); ctx.setLineCap(.round); ctx.setLineJoin(.round)
    ctx.addPath(checkPath(size: S * 0.34)); ctx.strokePath(); ctx.restoreGState()
    save(ctx, "D-lens-check.png")
}

func heartPath(size s: CGFloat) -> CGPath {
    let p = CGMutablePath()
    let bottom = CGPoint(x: 0, y: -s * 0.46)
    p.move(to: bottom)
    p.addCurve(to: CGPoint(x: -s * 0.5, y: s * 0.1), control1: CGPoint(x: -s * 0.22, y: -s * 0.3), control2: CGPoint(x: -s * 0.5, y: -s * 0.12))
    p.addArc(center: CGPoint(x: -s * 0.25, y: s * 0.1), radius: s * 0.25, startAngle: .pi, endAngle: 0, clockwise: true)
    p.addArc(center: CGPoint(x: s * 0.25, y: s * 0.1), radius: s * 0.25, startAngle: .pi, endAngle: 0, clockwise: true)
    p.addCurve(to: bottom, control1: CGPoint(x: s * 0.5, y: -s * 0.12), control2: CGPoint(x: s * 0.22, y: -s * 0.3))
    p.closeSubpath()
    return p
}

// E. A heart under the lens: look after your health.
func variantE() {
    let ctx = makeContext()
    gradient(ctx, 0x2FB457, 0x0E7A3A)
    let (c, _) = drawLens(ctx, color: rgb(0xFFFFFF))
    ctx.saveGState(); ctx.translateBy(x: c.x, y: c.y)
    ctx.setFillColor(rgb(0xFFFFFF)); ctx.addPath(heartPath(size: S * 0.30)); ctx.fillPath(); ctx.restoreGState()
    save(ctx, "E-lens-heart.png")
}

// F. The grade under the lens: a Nutri-Score green circle with a bold A, on near-black.
func variantF() {
    let ctx = makeContext()
    ctx.setFillColor(rgb(0x0A0A0A)); ctx.fill(CGRect(x: 0, y: 0, width: S, height: S))
    let (c, r) = drawLens(ctx, color: rgb(0xF5F5F5))
    ctx.setFillColor(rgb(0x2FB457))
    ctx.fillEllipse(in: CGRect(x: c.x - r * 0.66, y: c.y - r * 0.66, width: r * 1.32, height: r * 1.32))
    let font = CTFontCreateWithName("HelveticaNeue-Bold" as CFString, r * 1.05, nil)
    let text = NSAttributedString(string: "A", attributes: [kCTFontAttributeName as NSAttributedString.Key: font,
                                                             kCTForegroundColorAttributeName as NSAttributedString.Key: rgb(0xFFFFFF)])
    let line = CTLineCreateWithAttributedString(text)
    let bounds = CTLineGetImageBounds(line, ctx)
    ctx.textPosition = CGPoint(x: c.x - bounds.midX, y: c.y - bounds.midY)
    CTLineDraw(line, ctx)
    save(ctx, "F-lens-grade.png")
}


// G. A bowl under the lens with a leaf rising from it; the heart sits small at the upper left.
func variantG() {
    let ctx = makeContext()
    gradient(ctx, 0x2FB457, 0x0E7A3A)
    let (c, r) = drawLens(ctx, color: rgb(0xFFFFFF))
    let white = rgb(0xFFFFFF)
    ctx.beginTransparencyLayer(auxiliaryInfo: nil)
    // Bowl: the lower half of a disc, a rim line across the top, a small foot underneath.
    let bowlR = r * 0.46, rimY = c.y - r * 0.08
    ctx.setFillColor(white)
    ctx.move(to: CGPoint(x: c.x - bowlR, y: rimY))
    ctx.addArc(center: CGPoint(x: c.x, y: rimY), radius: bowlR, startAngle: .pi, endAngle: 0, clockwise: false)
    ctx.closePath(); ctx.fillPath()
    ctx.fill(CGRect(x: c.x - bowlR * 1.15, y: rimY - r * 0.01, width: bowlR * 2.3, height: r * 0.1))
    ctx.fill(CGRect(x: c.x - bowlR * 0.38, y: rimY - bowlR - r * 0.08, width: bowlR * 0.76, height: r * 0.09))
    // Leaf rising from the bowl, leaning right; its stem starts at the rim.
    drawLeaf(ctx, center: CGPoint(x: c.x + r * 0.12, y: rimY + r * 0.46), h: r * 0.66, w: r * 0.38, rotation: -0.5,
             fill: white, veinColor: nil, sideVeins: false)
    // Heart, small, upper left.
    ctx.saveGState(); ctx.translateBy(x: c.x - r * 0.42, y: rimY + r * 0.52)
    ctx.setFillColor(white); ctx.addPath(heartPath(size: r * 0.34)); ctx.fillPath(); ctx.restoreGState()
    ctx.endTransparencyLayer()
    save(ctx, "G-lens-bowl.png")
}

/// A contact sheet: every candidate at 180, 120 and 60 pixels with the home-screen corner mask,
/// side by side on a light and a dark background, so legibility at real sizes can be judged.
func sheet(_ names: [String]) {
    let cell: CGFloat = 400, rowH: CGFloat = 230
    let W = cell * CGFloat(names.count), H = rowH * 2
    let ctx = CGContext(data: nil, width: Int(W), height: Int(H), bitsPerComponent: 8, bytesPerRow: 0,
                        space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
    for (row, bg) in [(0, 0xF2F2F7), (1, 0x000000)].enumerated() {
        ctx.setFillColor(rgb(UInt32(bg.1))); ctx.fill(CGRect(x: 0, y: CGFloat(row) * rowH, width: W, height: rowH))
    }
    for (i, name) in names.enumerated() {
        let url = URL(fileURLWithPath: outDir).appendingPathComponent(name)
        guard let src = CGImageSourceCreateWithURL(url as CFURL, nil), let img = CGImageSourceCreateImageAtIndex(src, 0, nil) else { continue }
        for row in 0..<2 {
            var x = cell * CGFloat(i) + 20
            for size in [180.0, 120.0, 60.0] as [CGFloat] {
                let y = CGFloat(row) * rowH + (rowH - size) / 2
                let rect = CGRect(x: x, y: y, width: size, height: size)
                ctx.saveGState()
                ctx.addPath(CGPath(roundedRect: rect, cornerWidth: size * 0.2237, cornerHeight: size * 0.2237, transform: nil)); ctx.clip()
                ctx.interpolationQuality = .high
                ctx.draw(img, in: rect)
                ctx.restoreGState()
                x += size + 16
            }
        }
    }
    let url = URL(fileURLWithPath: outDir).appendingPathComponent("sheet.png")
    let dest = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil)!
    CGImageDestinationAddImage(dest, ctx.makeImage()!, nil); CGImageDestinationFinalize(dest)
    print("wrote sheet.png")
}


// MARK: Glyphs in unit coordinates (about -0.5...0.5), drawn white at `scale` around `at`.

func withGlyph(_ ctx: CGContext, at c: CGPoint, scale q: CGFloat, rotation: CGFloat = 0, _ body: (CGContext) -> Void) {
    ctx.saveGState(); ctx.translateBy(x: c.x, y: c.y); ctx.rotate(by: rotation); ctx.scaleBy(x: q, y: q)
    ctx.setLineCap(.round); ctx.setLineJoin(.round); ctx.setFillColor(rgb(0xFFFFFF)); ctx.setStrokeColor(rgb(0xFFFFFF))
    body(ctx); ctx.restoreGState()
}

/// A flexed arm as one silhouette, facing right: a long upper arm with the bicep bump on top, a deep
/// crease, then a tall forearm rising to a round fist that sits well above the bicep.
func muscleGlyph(_ ctx: CGContext) {
    let p = CGMutablePath()
    p.move(to: CGPoint(x: -0.56, y: -0.38))                                     // shoulder, underside
    p.addLine(to: CGPoint(x: 0.2, y: -0.38))                                     // underside of the upper arm
    p.addCurve(to: CGPoint(x: 0.47, y: -0.12),                                   // rounded elbow
               control1: CGPoint(x: 0.4, y: -0.38), control2: CGPoint(x: 0.47, y: -0.3))
    p.addLine(to: CGPoint(x: 0.43, y: 0.28))                                     // outer forearm, leaning in
    p.addCurve(to: CGPoint(x: 0.06, y: 0.3),                                     // the fist: a round knob that
               control1: CGPoint(x: 0.44, y: 0.64), control2: CGPoint(x: 0.02, y: 0.64))   // overhangs on the inside
    p.addCurve(to: CGPoint(x: 0.14, y: 0.14),                                    // tuck in under the fist
               control1: CGPoint(x: 0.08, y: 0.22), control2: CGPoint(x: 0.12, y: 0.18))
    p.addCurve(to: CGPoint(x: 0.1, y: -0.04),                                    // inner forearm to the crease
               control1: CGPoint(x: 0.16, y: 0.08), control2: CGPoint(x: 0.14, y: 0.0))
    p.addCurve(to: CGPoint(x: -0.56, y: -0.06),                                  // a lean bicep down to the shoulder
               control1: CGPoint(x: -0.04, y: 0.16), control2: CGPoint(x: -0.44, y: 0.18))
    p.closeSubpath()
    ctx.addPath(p); ctx.fillPath()
}

/// The arm alone, large, to judge the silhouette.
func muscleTest() {
    let ctx = makeContext()
    ctx.setFillColor(rgb(0x1E9A48)); ctx.fill(CGRect(x: 0, y: 0, width: S, height: S))
    withGlyph(ctx, at: CGPoint(x: S * 0.5, y: S * 0.5), scale: S * 0.8, rotation: -0.1, muscleGlyph)
    save(ctx, "muscle-test.png")
}

/// A carrot leaning right with three leaves.
func carrotGlyph(_ ctx: CGContext) {
    let p = CGMutablePath()
    p.move(to: CGPoint(x: -0.17, y: 0.1))
    p.addQuadCurve(to: CGPoint(x: 0.02, y: -0.5), control: CGPoint(x: -0.1, y: -0.18))
    p.addQuadCurve(to: CGPoint(x: 0.17, y: 0.1), control: CGPoint(x: 0.14, y: -0.18))
    p.addQuadCurve(to: CGPoint(x: -0.17, y: 0.1), control: CGPoint(x: 0, y: 0.2))
    ctx.addPath(p); ctx.fillPath()
    for r: CGFloat in [-0.55, 0, 0.55] {
        ctx.saveGState(); ctx.translateBy(x: 0, y: 0.12); ctx.rotate(by: r); ctx.translateBy(x: 0, y: 0.17)
        ctx.addPath(leafOutline(h: 0.34, w: 0.13)); ctx.fillPath()
        ctx.setBlendMode(.clear); ctx.setLineWidth(0.022)
        ctx.move(to: CGPoint(x: 0, y: -0.15)); ctx.addLine(to: CGPoint(x: 0.03, y: 0.1)); ctx.strokePath()
        ctx.restoreGState()
    }
}

func checkGlyph(_ ctx: CGContext) {
    ctx.setLineWidth(0.17); ctx.addPath(checkPath(size: 0.8)); ctx.strokePath()
}

/// Four rounded tiles in two greens with a glyph each; `lensInFourth` leaves the last tile to the lens.
func quadrants(_ ctx: CGContext, lensInFourth: Bool) {
    ctx.setFillColor(rgb(0x0B6B33)); ctx.fill(CGRect(x: 0, y: 0, width: S, height: S))
    let m = S * 0.075, g = S * 0.03, t = (S - 2 * m - g) / 2, rad = S * 0.07
    let tiles = [CGRect(x: m, y: m + t + g, width: t, height: t), CGRect(x: m + t + g, y: m + t + g, width: t, height: t),
                 CGRect(x: m, y: m, width: t, height: t), CGRect(x: m + t + g, y: m, width: t, height: t)]
    let fills: [UInt32] = [0x2FB457, 0x1E9A48, 0x1E9A48, 0x2FB457]
    for (i, r) in tiles.enumerated() {
        ctx.setFillColor(rgb(fills[i])); ctx.addPath(CGPath(roundedRect: r, cornerWidth: rad, cornerHeight: rad, transform: nil)); ctx.fillPath()
    }
    let q = lensInFourth ? t * 0.62 : t * 0.56
    // Glyphs sit a little toward the outer corners so the lens in the middle covers less of them.
    let off = lensInFourth ? 0 : t * 0.12
    let c0 = CGPoint(x: tiles[0].midX - off, y: tiles[0].midY + off)
    ctx.beginTransparencyLayer(auxiliaryInfo: nil)
    drawLeaf(ctx, center: c0, h: t * 0.62, w: t * 0.36, rotation: -0.45, fill: rgb(0xFFFFFF), veinColor: nil, sideVeins: true)
    ctx.endTransparencyLayer()
    withGlyph(ctx, at: CGPoint(x: tiles[1].midX + off, y: tiles[1].midY + off), scale: q * 1.1, rotation: -0.1, muscleGlyph)
    ctx.beginTransparencyLayer(auxiliaryInfo: nil)
    withGlyph(ctx, at: CGPoint(x: tiles[2].midX - off, y: tiles[2].midY - off), scale: q, rotation: 0.35, carrotGlyph)
    ctx.endTransparencyLayer()
    if !lensInFourth { withGlyph(ctx, at: CGPoint(x: tiles[3].midX + off * 1.5, y: tiles[3].midY - off * 1.5), scale: q * 0.92, checkGlyph) }
}

/// A lens with a soft shadow so it separates from whatever is beneath.
func overlayLens(_ ctx: CGContext, center: CGPoint, radius: CGFloat) {
    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -S * 0.01), blur: S * 0.03, color: CGColor(gray: 0, alpha: 0.35))
    ctx.setStrokeColor(rgb(0xFFFFFF)); ctx.setLineCap(.round)
    ctx.setLineWidth(radius * 0.26)
    ctx.addArc(center: center, radius: radius, startAngle: 0, endAngle: .pi * 2, clockwise: false); ctx.strokePath()
    let a: CGFloat = -.pi / 4
    ctx.setLineWidth(radius * 0.34)
    ctx.move(to: CGPoint(x: center.x + cos(a) * (radius + radius * 0.1), y: center.y + sin(a) * (radius + radius * 0.1)))
    ctx.addLine(to: CGPoint(x: center.x + cos(a) * (radius + radius * 0.75), y: center.y + sin(a) * (radius + radius * 0.75))); ctx.strokePath()
    ctx.restoreGState()
}

// H. Four glyphs, lens over the center.
func variantH() {
    let ctx = makeContext()
    quadrants(ctx, lensInFourth: false)
    overlayLens(ctx, center: CGPoint(x: S * 0.5, y: S * 0.5), radius: S * 0.185)
    save(ctx, "H-quadrants-lens.png")
}

// H2. Three glyphs; the lens takes the fourth tile and overlaps the center.
func variantH2() {
    let ctx = makeContext()
    quadrants(ctx, lensInFourth: true)
    overlayLens(ctx, center: CGPoint(x: S * 0.66, y: S * 0.36), radius: S * 0.19)
    save(ctx, "H2-quadrants-lens.png")
}

variantA(); variantA2(); variantB(); variantC(); variantD(); variantE(); variantF(); variantG(); variantH(); variantH2(); muscleTest()
sheet(["H-quadrants-lens.png", "H2-quadrants-lens.png", "D-lens-check.png", "F-lens-grade.png", "G-lens-bowl.png"])
