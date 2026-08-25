#if canImport(AppKit)
import AppKit

public extension NSImage {
    func labPixelImage(maxDimension: Int = PaletteQuality.balanced.maxDimension) async throws -> PixelImage {
        guard let cgImage = cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            throw ImagePixelReaderError.cannotReadImage
        }
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
#endif
