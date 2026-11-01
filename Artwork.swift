import AppKit

extension NSImage {
    /// A color that represents the artwork, usable as an accent: an average that favours vivid pixels,
    /// pushed to a readable saturation/brightness. Greyscale art stays grey.
    var vividColor: NSColor? {
        guard let cg = cgImage(forProposedRect: nil, context: nil, hints: nil) else { return nil }
        let n = 12
        var px = [UInt8](repeating: 0, count: n * n * 4)
        let drawn = px.withUnsafeMutableBytes { buf -> Bool in
            guard let ctx = CGContext(data: buf.baseAddress, width: n, height: n, bitsPerComponent: 8, bytesPerRow: n * 4,
                                      space: CGColorSpace(name: CGColorSpace.sRGB)!,
                                      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return false }
            ctx.draw(cg, in: CGRect(x: 0, y: 0, width: n, height: n))
            return true
        }
        guard drawn else { return nil }
        var r = 0.0, g = 0.0, b = 0.0, total = 0.0
        for i in stride(from: 0, to: px.count, by: 4) {
            let c = NSColor(srgbRed: Double(px[i]) / 255, green: Double(px[i + 1]) / 255, blue: Double(px[i + 2]) / 255, alpha: 1)
            let w = c.saturationComponent * c.saturationComponent * c.brightnessComponent + 0.01
            r += c.redComponent * w; g += c.greenComponent * w; b += c.blueComponent * w; total += w
        }
        let avg = NSColor(srgbRed: r / total, green: g / total, blue: b / total, alpha: 1)
        let s = avg.saturationComponent
        return NSColor(hue: avg.hueComponent, saturation: s < 0.12 ? s : max(s, 0.5),
                       brightness: min(max(avg.brightnessComponent, 0.55), 0.85), alpha: 1)
    }
}
