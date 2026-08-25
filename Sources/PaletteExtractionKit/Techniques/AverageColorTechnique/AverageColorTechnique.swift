import Foundation

public struct AverageColorOptions: Sendable {
    public var quality: PaletteQuality
    public var minimumAlpha: UInt8

    public init(quality: PaletteQuality = .balanced, minimumAlpha: UInt8 = 128) {
        self.quality = quality
        self.minimumAlpha = minimumAlpha
    }
}

/// Trivial by design: the mean color of the whole image, one swatch. No `colorCount` —
/// it's meaningless for a single-output technique, so it's omitted rather than ignored.
public struct AverageColorTechnique: PaletteExtractionTechnique {
    public var name: String { "Average color" }
    public var description: String { "Mean color across the whole image" }
    public var options: AverageColorOptions

    public init(options: AverageColorOptions = .init()) {
        self.options = options
    }

    public func extract(from image: PixelImage) async -> [PaletteColor] {
        await Self.extractAsync(from: image.pixels, options: options)
    }

    public static func extract(from pixels: [RGBColor], options: AverageColorOptions = .init()) -> [PaletteColor] {
        let filtered = pixels.filter { $0.alpha >= options.minimumAlpha }
        guard !filtered.isEmpty else { return [] }
        let sampled = strideSample(filtered, limit: options.quality.maxSamples)

        var sum = LabVector.zero
        for pixel in sampled {
            sum += ColorConverter.lab(from: pixel).vector
        }
        let lab = LabColor(vector: sum / Float(sampled.count))
        let rgb = ColorConverter.rgb(from: lab)

        return [PaletteColor(rgb: rgb, lab: lab, population: sampled.count, percentage: 1)]
    }

    public static func extractAsync(from pixels: [RGBColor], options: AverageColorOptions = .init()) async -> [PaletteColor] {
        await Task.detached(priority: .userInitiated) {
            extract(from: pixels, options: options)
        }.value
    }

    private static func strideSample<T>(_ input: [T], limit: Int) -> [T] {
        guard input.count > limit else { return input }
        let step = Double(input.count) / Double(limit)
        return (0..<limit).map { input[Int(Double($0) * step)] }
    }
}
