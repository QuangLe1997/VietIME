// Vẽ biểu tượng "Vi" dạng template (đen trên nền trong) cho thanh menu.
// swift scripts/make-icon.swift <out.tiff>
import AppKit

let out = CommandLine.arguments[1]
let image = NSImage(size: NSSize(width: 16, height: 16))
for scale in [1, 2] {
    let px = 16 * scale
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: px, pixelsHigh: px, bitsPerSample: 8,
                               samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                               colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    rep.size = NSSize(width: 16, height: 16)
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    let text = NSAttributedString(string: "Vi", attributes: [
        .font: NSFont.systemFont(ofSize: 11, weight: .bold),
        .foregroundColor: NSColor.black,
    ])
    let sz = text.size()
    text.draw(at: NSPoint(x: (16 - sz.width) / 2, y: (16 - sz.height) / 2))
    NSGraphicsContext.restoreGraphicsState()
    image.addRepresentation(rep)
}
try! image.tiffRepresentation!.write(to: URL(fileURLWithPath: out))
