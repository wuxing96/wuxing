import AppKit
import Foundation

struct StatusIcon {
    let name: String
    let column: Int
}

let icons = [
    StatusIcon(name: "mushi-status-working", column: 0),
    StatusIcon(name: "mushi-status-waiting", column: 1),
    StatusIcon(name: "mushi-status-done", column: 2),
    StatusIcon(name: "mushi-status-idle", column: 3),
    StatusIcon(name: "mushi-status-header", column: 4)
]

let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let sourceURL = root.appendingPathComponent("resources/Assets/mushi-status/mushi-status-sprite-v1.png")
let outputDirectory = root.appendingPathComponent("resources/Assets/mushi-status")

guard let source = NSImage(contentsOf: sourceURL),
      let cgImage = source.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
    fatalError("Could not load \(sourceURL.path)")
}

let sourceWidth = cgImage.width
let sourceHeight = cgImage.height
let bytesPerPixel = 4

func rgbaPixels(from image: CGImage) -> ([UInt8], Int, Int, Int) {
    let width = image.width
    let height = image.height
    let bytesPerRow = width * bytesPerPixel
    var pixels = [UInt8](repeating: 0, count: height * bytesPerRow)
    guard let context = CGContext(
        data: &pixels,
        width: width,
        height: height,
        bitsPerComponent: 8,
        bytesPerRow: bytesPerRow,
        space: CGColorSpaceCreateDeviceRGB(),
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    ) else {
        fatalError("Could not create source bitmap context")
    }
    context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
    return (pixels, width, height, bytesPerRow)
}

func keyedAlpha(red: UInt8, green: UInt8, blue: UInt8) -> UInt8 {
    let r = Double(red)
    let g = Double(green)
    let b = Double(blue)
    let distance = sqrt(pow(r - 255, 2) + pow(g, 2) + pow(b - 255, 2))
    guard r > 150, b > 150, g < 145 else {
        return 255
    }
    if distance <= 80 {
        return 0
    }
    if distance >= 150 {
        return 255
    }
    return UInt8(((distance - 80) / 70 * 255).rounded())
}

func transparentImage(from image: CGImage) -> CGImage {
    var (pixels, width, height, bytesPerRow) = rgbaPixels(from: image)
    for offset in stride(from: 0, to: pixels.count, by: bytesPerPixel) {
        let alpha = keyedAlpha(
            red: pixels[offset],
            green: pixels[offset + 1],
            blue: pixels[offset + 2]
        )
        if alpha < 255 {
            pixels[offset + 3] = alpha
            if alpha == 0 {
                pixels[offset] = 0
                pixels[offset + 1] = 0
                pixels[offset + 2] = 0
            }
        }
    }

    guard let context = CGContext(
        data: &pixels,
        width: width,
        height: height,
        bitsPerComponent: 8,
        bytesPerRow: bytesPerRow,
        space: CGColorSpaceCreateDeviceRGB(),
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    ),
    let result = context.makeImage() else {
        fatalError("Could not create transparent image")
    }
    return result
}

func tightSquareCrop(from image: CGImage) -> CGImage {
    let (pixels, width, height, bytesPerRow) = rgbaPixels(from: image)
    var minX = width
    var minY = height
    var maxX = 0
    var maxY = 0

    for y in 0..<height {
        for x in 0..<width {
            let offset = y * bytesPerRow + x * bytesPerPixel
            if pixels[offset + 3] > 10 {
                minX = min(minX, x)
                minY = min(minY, y)
                maxX = max(maxX, x)
                maxY = max(maxY, y)
            }
        }
    }

    guard minX <= maxX, minY <= maxY else {
        return image
    }

    let padding = 32
    let contentWidth = maxX - minX + 1
    let contentHeight = maxY - minY + 1
    let side = max(contentWidth, contentHeight) + padding * 2
    let bytesPerRowOut = side * bytesPerPixel
    var output = [UInt8](repeating: 0, count: side * bytesPerRowOut)
    let originX = (side - contentWidth) / 2
    let originY = (side - contentHeight) / 2

    for y in 0..<contentHeight {
        let srcY = minY + y
        let dstY = originY + y
        let srcOffset = srcY * bytesPerRow + minX * bytesPerPixel
        let dstOffset = dstY * bytesPerRowOut + originX * bytesPerPixel
        output.replaceSubrange(dstOffset..<(dstOffset + contentWidth * bytesPerPixel), with: pixels[srcOffset..<(srcOffset + contentWidth * bytesPerPixel)])
    }

    guard let context = CGContext(
        data: &output,
        width: side,
        height: side,
        bitsPerComponent: 8,
        bytesPerRow: bytesPerRowOut,
        space: CGColorSpaceCreateDeviceRGB(),
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    ),
    let result = context.makeImage() else {
        fatalError("Could not create square icon")
    }
    return result
}

func writePNG(_ image: CGImage, to url: URL) {
    guard let data = NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:]) else {
        fatalError("Could not encode \(url.path)")
    }
    try! data.write(to: url)
}

for icon in icons {
    let x0 = Int((Double(sourceWidth) / 5.0 * Double(icon.column)).rounded(.down))
    let x1 = Int((Double(sourceWidth) / 5.0 * Double(icon.column + 1)).rounded(.down))
    let cropRect = CGRect(x: x0, y: 0, width: x1 - x0, height: sourceHeight)
    guard let cropped = cgImage.cropping(to: cropRect) else {
        fatalError("Could not crop column \(icon.column)")
    }
    let transparent = transparentImage(from: cropped)
    let square = tightSquareCrop(from: transparent)
    let outputURL = outputDirectory.appendingPathComponent("\(icon.name).png")
    writePNG(square, to: outputURL)
    print(outputURL.path)
}
