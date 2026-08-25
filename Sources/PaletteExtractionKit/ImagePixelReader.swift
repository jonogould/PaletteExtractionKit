#if canImport(CoreGraphics)
import CoreGraphics
import Foundation

public enum ImagePixelReaderError: Error, Sendable {
    case cannotCreateContext
    case cannotReadImage
}

public enum ImagePixelReader {
    public static func pixelImage(from cgImage: CGImage, maxDimension: Int = 160) throws -> PixelImage {
        let width = cgImage.width
        let height = cgImage.height
        guard width > 0, height > 0 else { return PixelImage(pixels: [], width: 0, height: 0) }

        let scale = min(1.0, Double(maxDimension) / Double(max(width, height)))
        let scaledWidth = max(1, Int(Double(width) * scale))
        let scaledHeight = max(1, Int(Double(height) * scale))
        let bytesPerPixel = 4
        let bytesPerRow = scaledWidth * bytesPerPixel
        var data = [UInt8](repeating: 0, count: scaledHeight * bytesPerRow)

        guard let context = CGContext(
            data: &data,
            width: scaledWidth,
            height: scaledHeight,
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue
        ) else {
            throw ImagePixelReaderError.cannotCreateContext
        }

        context.interpolationQuality = .medium
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: scaledWidth, height: scaledHeight))

        var pixels: [RGBColor] = []
        pixels.reserveCapacity(scaledWidth * scaledHeight)
        for index in stride(from: 0, to: data.count, by: bytesPerPixel) {
            pixels.append(RGBColor(red: data[index], green: data[index + 1], blue: data[index + 2], alpha: data[index + 3]))
        }
        return PixelImage(pixels: pixels, width: scaledWidth, height: scaledHeight)
    }

    public static func pixels(from cgImage: CGImage, maxDimension: Int = 160) throws -> [RGBColor] {
        try pixelImage(from: cgImage, maxDimension: maxDimension).pixels
    }

    public static func pixelImageAsync(from cgImage: CGImage, maxDimension: Int = 160) async throws -> PixelImage {
        try await Task.detached(priority: .userInitiated) {
            try pixelImage(from: cgImage, maxDimension: maxDimension)
        }.value
    }

    public static func pixelsAsync(from cgImage: CGImage, maxDimension: Int = 160) async throws -> [RGBColor] {
        try await pixelImageAsync(from: cgImage, maxDimension: maxDimension).pixels
    }
}
#endif
