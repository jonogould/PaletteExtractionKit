#if canImport(UIKit)
import UIKit

public extension UIImage {
    func labPixelImage(maxDimension: Int = 160) async throws -> PixelImage {
        guard let cgImage else { throw ImagePixelReaderError.cannotReadImage }
        return try await ImagePixelReader.pixelImageAsync(from: cgImage, maxDimension: maxDimension)
    }

    func labPalette(quality: PaletteQuality = .balanced, using technique: some PaletteExtractionTechnique) async throws -> [PaletteColor] {
        let image = try await labPixelImage(maxDimension: quality.maxDimension)
        return await PaletteExtractor.extract(from: image, using: technique)
    }

    func labPalettes(quality: PaletteQuality = .balanced, using techniques: [any PaletteExtractionTechnique] = [KMeansTechnique(), FloodFillTechnique()]) async throws -> [ExtractedPalette] {
        let image = try await labPixelImage(maxDimension: quality.maxDimension)
        return await PaletteExtractor.extractMany(from: image, using: techniques)
    }
}

public extension PaletteColor {
    var uiColor: UIColor {
        UIColor(
            red: CGFloat(rgb.red) / 255,
            green: CGFloat(rgb.green) / 255,
            blue: CGFloat(rgb.blue) / 255,
            alpha: CGFloat(rgb.alpha) / 255
        )
    }
}
#endif
