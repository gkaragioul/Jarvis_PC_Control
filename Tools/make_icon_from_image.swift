import AppKit
import ImageIO

let arguments = Array(CommandLine.arguments.dropFirst())
guard arguments.count >= 2 else {
    fatalError("Usage: swift Tools/make_icon_from_image.swift <source.png> <output.iconset> [cropX cropY cropWidth cropHeight contentScale]")
}

let sourceURL = URL(fileURLWithPath: arguments[0])
let outputURL = URL(fileURLWithPath: arguments[1])

guard let source = CGImageSourceCreateWithURL(sourceURL as CFURL, nil),
      let cgImage = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
    fatalError("Could not read source image: \(sourceURL.path)")
}

let width = cgImage.width
let height = cgImage.height
let defaultWidth = width
let defaultHeight = height
let cropX = arguments.count > 2 ? Int(arguments[2])! : 0
let cropY = arguments.count > 3 ? Int(arguments[3])! : 0
let cropWidth = arguments.count > 4 ? Int(arguments[4])! : defaultWidth
let cropHeight = arguments.count > 5 ? Int(arguments[5])! : defaultHeight
let contentScale = arguments.count > 6 ? CGFloat(Double(arguments[6])!) : 0.72

let safeRect = CGRect(
    x: max(0, min(cropX, width - cropWidth)),
    y: max(0, min(cropY, height - cropHeight)),
    width: min(cropWidth, width),
    height: min(cropHeight, height)
)

guard let cropped = cgImage.cropping(to: safeRect) else {
    fatalError("Could not crop source image")
}

try? FileManager.default.removeItem(at: outputURL)
try FileManager.default.createDirectory(at: outputURL, withIntermediateDirectories: true)

let specs: [(String, Int)] = [
    ("icon_16x16.png", 16),
    ("icon_16x16@2x.png", 32),
    ("icon_32x32.png", 32),
    ("icon_32x32@2x.png", 64),
    ("icon_128x128.png", 128),
    ("icon_128x128@2x.png", 256),
    ("icon_256x256.png", 256),
    ("icon_256x256@2x.png", 512),
    ("icon_512x512.png", 512),
    ("icon_512x512@2x.png", 1024),
]

func resizedPNG(from image: CGImage, side: Int) -> Data {
    let colorSpace = CGColorSpace(name: CGColorSpace.sRGB)!
    guard let context = CGContext(
        data: nil,
        width: side,
        height: side,
        bitsPerComponent: 8,
        bytesPerRow: 0,
        space: colorSpace,
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    ) else {
        fatalError("Could not create drawing context")
    }

    context.interpolationQuality = .high

    let canvas = CGFloat(side)
    let background = CGGradient(
        colorsSpace: colorSpace,
        colors: [
            CGColor(red: 0.025, green: 0.027, blue: 0.035, alpha: 1),
            CGColor(red: 0.080, green: 0.083, blue: 0.100, alpha: 1)
        ] as CFArray,
        locations: [0.0, 1.0]
    )!
    context.drawLinearGradient(
        background,
        start: CGPoint(x: 0, y: canvas),
        end: CGPoint(x: canvas, y: 0),
        options: []
    )

    let maxImageSide = canvas * min(max(contentScale, 0.40), 1.0)
    let sourceAspect = CGFloat(image.width) / CGFloat(image.height)
    let imageWidth: CGFloat
    let imageHeight: CGFloat
    if sourceAspect >= 1 {
        imageWidth = maxImageSide
        imageHeight = maxImageSide / sourceAspect
    } else {
        imageHeight = maxImageSide
        imageWidth = maxImageSide * sourceAspect
    }
    let imageRect = CGRect(
        x: (canvas - imageWidth) / 2,
        y: (canvas - imageHeight) / 2,
        width: imageWidth,
        height: imageHeight
    )

    context.setShadow(offset: CGSize(width: 0, height: -canvas * 0.025), blur: canvas * 0.045, color: CGColor(gray: 0, alpha: 0.55))
    context.draw(image, in: imageRect)
    context.setShadow(offset: .zero, blur: 0, color: nil)

    guard let outputImage = context.makeImage() else {
        fatalError("Could not render resized icon")
    }

    let bitmap = NSBitmapImageRep(cgImage: outputImage)
    guard let data = bitmap.representation(using: .png, properties: [:]) else {
        fatalError("Could not encode PNG")
    }
    return data
}

for (name, side) in specs {
    let data = resizedPNG(from: cropped, side: side)
    try data.write(to: outputURL.appendingPathComponent(name))
}
