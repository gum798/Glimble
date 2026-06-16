import AppKit

// Renders a simple Glimble app icon: a white gesture glyph on a solid rounded-square.
// Usage: swift scripts/make-icon.swift <out.png>
let outPath = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "icon-1024.png"
let dim: CGFloat = 1024

/// A symbol rasterized white on a transparent background (reliable tint via sourceAtop).
func whiteSymbol(_ name: String, pointSize: CGFloat) -> NSImage? {
    let cfg = NSImage.SymbolConfiguration(pointSize: pointSize, weight: .semibold)
    guard let base = NSImage(systemSymbolName: name, accessibilityDescription: nil)?
        .withSymbolConfiguration(cfg) else { return nil }
    let s = base.size
    let img = NSImage(size: s)
    img.lockFocus()
    base.draw(at: .zero, from: NSRect(origin: .zero, size: s), operation: .sourceOver, fraction: 1)
    NSColor.white.set()
    NSRect(origin: .zero, size: s).fill(using: .sourceAtop)
    img.unlockFocus()
    return img
}

let image = NSImage(size: NSSize(width: dim, height: dim))
image.lockFocus()

// Solid rounded-square background.
let inset = dim * 0.08
let rect = NSRect(x: inset, y: inset, width: dim - inset * 2, height: dim - inset * 2)
NSBezierPath(roundedRect: rect, xRadius: dim * 0.225, yRadius: dim * 0.225).fill()
NSColor(srgbRed: 0.16, green: 0.42, blue: 0.92, alpha: 1).setFill()
NSBezierPath(roundedRect: rect, xRadius: dim * 0.225, yRadius: dim * 0.225).fill()

// Centered white glyph.
if let sym = whiteSymbol("hand.tap.fill", pointSize: dim * 0.46) {
    let s = sym.size
    sym.draw(in: NSRect(x: (dim - s.width) / 2, y: (dim - s.height) / 2, width: s.width, height: s.height))
}

image.unlockFocus()

guard let tiff = image.tiffRepresentation,
      let rep = NSBitmapImageRep(data: tiff),
      let png = rep.representation(using: .png, properties: [:]) else {
    FileHandle.standardError.write(Data("Failed to render icon\n".utf8))
    exit(1)
}
try png.write(to: URL(fileURLWithPath: outPath))
print("Wrote \(outPath)")
