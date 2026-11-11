import AppKit

// Drawn on a 1024-point canvas using the macOS icon grid: an 824-point rounded square centred with a 100-point margin.
func drawIcon(in ctx: CGContext, scale: CGFloat) {
    let srgb = CGColorSpace(name: CGColorSpace.sRGB)!
    let top = CGColor(srgbRed: 0.40, green: 0.80, blue: 1.00, alpha: 1)
    let bottom = CGColor(srgbRed: 0.00, green: 0.42, blue: 0.90, alpha: 1)
    let body = CGPath(roundedRect: CGRect(x: 100, y: 100, width: 824, height: 824), cornerWidth: 185, cornerHeight: 185, transform: nil)

    // Shadow offset and blur are in device pixels and ignore the CTM, so they are scaled by hand.
    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -12 * scale), blur: 24 * scale, color: CGColor(gray: 0, alpha: 0.3))
    ctx.addPath(body)
    ctx.setFillColor(bottom)
    ctx.fillPath()
    ctx.restoreGState()

    ctx.saveGState()
    ctx.addPath(body)
    ctx.clip()
    let gradient = CGGradient(colorsSpace: srgb, colors: [top, bottom] as CFArray, locations: [0, 1])!
    ctx.drawLinearGradient(gradient, start: CGPoint(x: 512, y: 924), end: CGPoint(x: 512, y: 100), options: [])
    ctx.restoreGState()

    let drop = CGMutablePath()
    drop.move(to: CGPoint(x: 512, y: 800))
    drop.addCurve(to: CGPoint(x: 312, y: 420), control1: CGPoint(x: 470, y: 720), control2: CGPoint(x: 312, y: 560))
    drop.addArc(center: CGPoint(x: 512, y: 420), radius: 200, startAngle: .pi, endAngle: 2 * .pi, clockwise: false)
    drop.addCurve(to: CGPoint(x: 512, y: 800), control1: CGPoint(x: 712, y: 560), control2: CGPoint(x: 554, y: 720))
    drop.closeSubpath()

    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -10 * scale), blur: 30 * scale, color: CGColor(srgbRed: 0, green: 0.2, blue: 0.5, alpha: 0.35))
    ctx.addPath(drop)
    ctx.setFillColor(CGColor(gray: 1, alpha: 1))
    ctx.fillPath()
    ctx.restoreGState()

    ctx.setStrokeColor(CGColor(srgbRed: 0.72, green: 0.87, blue: 1, alpha: 1))
    ctx.setLineWidth(30)
    ctx.setLineCap(.round)
    ctx.addArc(center: CGPoint(x: 512, y: 420), radius: 130, startAngle: .pi * 1.05, endAngle: .pi * 1.35, clockwise: false)
    ctx.strokePath()
}

func png(pixels: Int) -> Data {
    let ctx = CGContext(data: nil, width: pixels, height: pixels, bitsPerComponent: 8, bytesPerRow: 0,
                        space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    let scale = CGFloat(pixels) / 1024
    ctx.scaleBy(x: scale, y: scale)
    drawIcon(in: ctx, scale: scale)
    return NSBitmapImageRep(cgImage: ctx.makeImage()!).representation(using: .png, properties: [:])!
}

let iconset = URL(fileURLWithPath: CommandLine.arguments[1])
try FileManager.default.createDirectory(at: iconset, withIntermediateDirectories: true)
for points in [16, 32, 128, 256, 512] {
    try png(pixels: points).write(to: iconset.appendingPathComponent("icon_\(points)x\(points).png"))
    try png(pixels: points * 2).write(to: iconset.appendingPathComponent("icon_\(points)x\(points)@2x.png"))
}
