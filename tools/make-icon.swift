import AppKit

// Silver Rain Mini's app icon, in the house style of AllyClicker, AllyKeyboard and SmartNav:
// a 1024 canvas, the tile inset 96 px with corners at 23 % of its side, a vertical gradient,
// a white sheen over the upper half. Unlike its siblings' white glyphs, the glyph here is the
// station's own logo in its three colours, so the tile is silver rather than a hue.
// Usage: make-icon <StationLogo.svg> <out.png>
let args = CommandLine.arguments
guard args.count == 3, let logo = NSImage(contentsOfFile: args[1]) else {
    fatalError("usage: make-icon <StationLogo.svg> <out.png>")
}

func rgb(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat, _ a: CGFloat = 1) -> CGColor {
    CGColor(srgbRed: r / 255, green: g / 255, blue: b / 255, alpha: a)
}
let tileTop = rgb(255, 255, 255), tileBottom = rgb(214, 220, 232)
let glyphShadow = rgb(0, 30, 110, 0.25)  // the logo's navy, soft

let size = 1024, canvas = CGFloat(size), inset: CGFloat = 96, body = canvas - 2 * inset
let space = CGColorSpace(name: CGColorSpace.sRGB)!
let cg = CGContext(data: nil, width: size, height: size, bitsPerComponent: 8, bytesPerRow: 0,
                   space: space, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
let tile = CGRect(x: inset, y: inset, width: body, height: body)

// The tile and its sheen.
cg.saveGState()
cg.addPath(CGPath(roundedRect: tile, cornerWidth: body * 0.23, cornerHeight: body * 0.23, transform: nil))
cg.clip()
let fill = CGGradient(colorsSpace: space, colors: [tileTop, tileBottom] as CFArray, locations: [0, 1])!
cg.drawLinearGradient(fill, start: CGPoint(x: 0, y: tile.maxY), end: CGPoint(x: 0, y: tile.minY), options: [])
let sheen = CGGradient(colorsSpace: space, colors: [rgb(255, 255, 255, 0.35), rgb(255, 255, 255, 0)] as CFArray,
                       locations: [0, 1])!
cg.drawLinearGradient(sheen, start: CGPoint(x: 0, y: tile.maxY), end: CGPoint(x: 0, y: tile.midY), options: [])
cg.restoreGState()

// The logo, 68 % of the tile wide and 6 % of it below the centre.
let width = body * 0.68, height = width * logo.size.height / logo.size.width
let rect = CGRect(x: tile.midX - width / 2, y: tile.midY - height / 2 - body * 0.06, width: width, height: height)
var proposed = CGRect(x: 0, y: 0, width: size, height: size)
let image = logo.cgImage(forProposedRect: &proposed, context: nil, hints: nil)!
cg.setShadow(offset: CGSize(width: 0, height: -20), blur: 29, color: glyphShadow)
cg.draw(image, in: rect)

let out = CGImageDestinationCreateWithURL(URL(filePath: args[2]) as CFURL, "public.png" as CFString, 1, nil)!
CGImageDestinationAddImage(out, cg.makeImage()!, nil)
guard CGImageDestinationFinalize(out) else { fatalError("could not write \(args[2])") }
