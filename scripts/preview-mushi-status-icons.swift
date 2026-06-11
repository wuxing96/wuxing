import AppKit
import Foundation

let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let names = [
    "mushi-status-working",
    "mushi-status-waiting",
    "mushi-status-done",
    "mushi-status-idle",
    "mushi-status-header"
]
let labels = ["working", "waiting", "done", "idle", "header"]
let output = root.appendingPathComponent("resources/Assets/mushi-status/mushi-status-preview.png")
let canvasSize = CGSize(width: 900, height: 220)
let image = NSImage(size: canvasSize)

image.lockFocus()
NSColor(calibratedWhite: 0.08, alpha: 1).setFill()
NSBezierPath(rect: NSRect(origin: .zero, size: canvasSize)).fill()

for (index, name) in names.enumerated() {
    let x = CGFloat(index) * 180 + 28
    let url = root.appendingPathComponent("resources/Assets/mushi-status/\(name).png")
    guard let icon = NSImage(contentsOf: url) else {
        continue
    }
    icon.draw(
        in: NSRect(x: x, y: 78, width: 124, height: 124),
        from: .zero,
        operation: .sourceOver,
        fraction: 1,
        respectFlipped: false,
        hints: [.interpolation: NSImageInterpolation.high]
    )
    icon.draw(
        in: NSRect(x: x + 46, y: 44, width: 32, height: 32),
        from: .zero,
        operation: .sourceOver,
        fraction: 1,
        respectFlipped: false,
        hints: [.interpolation: NSImageInterpolation.high]
    )
    NSString(string: labels[index]).draw(
        in: NSRect(x: x, y: 18, width: 124, height: 18),
        withAttributes: [
            .font: NSFont.systemFont(ofSize: 12, weight: .medium),
            .foregroundColor: NSColor.white.withAlphaComponent(0.76)
        ]
    )
}

image.unlockFocus()

guard let tiff = image.tiffRepresentation,
      let bitmap = NSBitmapImageRep(data: tiff),
      let png = bitmap.representation(using: .png, properties: [:]) else {
    fatalError("Could not render preview")
}
try png.write(to: output)
print(output.path)
