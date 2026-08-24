import Foundation
import ImageIO
import RestageBrand
import UniformTypeIdentifiers

/// iconutil이 먹는 .iconset 디렉터리를 만든다. 번들 빌드 때만 쓰는 도구라 배포물에는
/// 들어가지 않는다.

let variants: [(name: String, pixels: Int)] = [
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

func fail(_ message: String) -> Never {
    FileHandle.standardError.write(Data((message + "\n").utf8))
    exit(1)
}

guard CommandLine.arguments.count == 2 else {
    fail("usage: restage-icon <path to the .iconset to write>")
}

let output = URL(fileURLWithPath: CommandLine.arguments[1])
do {
    try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
} catch {
    fail("couldn't create the iconset directory: \(output.path): \(error)")
}

for variant in variants {
    guard let image = AppIconRenderer.render(pixels: variant.pixels) else {
        fail("couldn't render the icon: \(variant.name)")
    }
    let file = output.appendingPathComponent(variant.name)
    guard let destination = CGImageDestinationCreateWithURL(
        file as CFURL, UTType.png.identifier as CFString, 1, nil
    ) else {
        fail("couldn't open the PNG for writing: \(file.path)")
    }
    CGImageDestinationAddImage(destination, image, nil)
    guard CGImageDestinationFinalize(destination) else {
        fail("couldn't write the PNG: \(file.path)")
    }
}

print("wrote \(variants.count) icons: \(output.path)")
