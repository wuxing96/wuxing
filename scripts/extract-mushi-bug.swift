import AppKit
import Foundation

struct RGBA {
    var red: UInt8
    var green: UInt8
    var blue: UInt8
    var alpha: UInt8
}

let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let sourceURL = root.appendingPathComponent("resources/Assets/mushi-signal-cover.png")
let outputURL = root.appendingPathComponent("resources/Assets/mushi-bug.png")

guard let sourceImage = NSImage(contentsOf: sourceURL),
      let cgImage = sourceImage.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
    fatalError("Could not load \(sourceURL.path)")
}

let crop = CGRect(x: 210, y: 195, width: 900, height: 910)
guard let croppedImage = cgImage.cropping(to: crop) else {
    fatalError("Could not crop source image")
}

let width = croppedImage.width
let height = croppedImage.height
let bytesPerPixel = 4
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
    fatalError("Could not create bitmap context")
}

context.draw(croppedImage, in: CGRect(x: 0, y: 0, width: width, height: height))

func pixelOffset(x: Int, y: Int) -> Int {
    y * bytesPerRow + x * bytesPerPixel
}

func pixel(at x: Int, _ y: Int) -> RGBA {
    let offset = pixelOffset(x: x, y: y)
    return RGBA(
        red: pixels[offset],
        green: pixels[offset + 1],
        blue: pixels[offset + 2],
        alpha: pixels[offset + 3]
    )
}

func luma(_ pixel: RGBA) -> Double {
    0.2126 * Double(pixel.red) + 0.7152 * Double(pixel.green) + 0.0722 * Double(pixel.blue)
}

func isBackground(_ pixel: RGBA, x: Int, y: Int) -> Bool {
    let red = Int(pixel.red)
    let green = Int(pixel.green)
    let blue = Int(pixel.blue)
    let maxChannel = max(red, green, blue)
    let minEdgeDistance = min(x, y, width - 1 - x, height - 1 - y)
    let isTealBackdrop = red < 76 && green > 42 && blue > 48 && blue >= green - 22 && maxChannel < 166
    let isDarkBackdrop = red < 48 && green < 70 && blue < 76
    let isGlowBackdrop = red < 72 && green > red + 26 && blue > red + 18 && maxChannel < 166
    let isFrameAtEdge = minEdgeDistance < 28 && red > 95 && green > 70 && blue < 105
    return isTealBackdrop || isDarkBackdrop || isGlowBackdrop || isFrameAtEdge
}

var visited = [Bool](repeating: false, count: width * height)
var queue: [(Int, Int)] = []
queue.reserveCapacity(width * height / 3)

func enqueueIfBackground(_ x: Int, _ y: Int) {
    guard x >= 0, y >= 0, x < width, y < height else {
        return
    }
    let index = y * width + x
    guard !visited[index] else {
        return
    }
    visited[index] = true
    if isBackground(pixel(at: x, y), x: x, y: y) {
        queue.append((x, y))
    }
}

for x in 0..<width {
    enqueueIfBackground(x, 0)
    enqueueIfBackground(x, height - 1)
}
for y in 0..<height {
    enqueueIfBackground(0, y)
    enqueueIfBackground(width - 1, y)
}

var readIndex = 0
while readIndex < queue.count {
    let (x, y) = queue[readIndex]
    readIndex += 1

    let offset = pixelOffset(x: x, y: y)
    pixels[offset + 3] = 0

    enqueueIfBackground(x + 1, y)
    enqueueIfBackground(x - 1, y)
    enqueueIfBackground(x, y + 1)
    enqueueIfBackground(x, y - 1)
}

guard let outputCGImage = context.makeImage(),
      let representation = NSBitmapImageRep(cgImage: outputCGImage)
        .representation(using: .png, properties: [:]) else {
    fatalError("Could not encode output image")
}

try representation.write(to: outputURL)
print(outputURL.path)
