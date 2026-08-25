import Foundation

public struct ModifiedMedianCutOptions: Sendable {
    public var colorCount: Int
    public var quality: PaletteQuality
    public var minimumAlpha: UInt8

    public init(colorCount: Int = 4, quality: PaletteQuality = .balanced, minimumAlpha: UInt8 = 128) {
        self.colorCount = max(1, colorCount)
        self.quality = quality
        self.minimumAlpha = minimumAlpha
    }
}

/// MMCQ — the algorithm behind "color-thief" and its many ports.
public struct ModifiedMedianCutTechnique: PaletteExtractionTechnique {
    public var name: String { "MMCQ" }
    public var description: String { "Modified median cut — the color-thief algorithm" }
    public var options: ModifiedMedianCutOptions

    public init(options: ModifiedMedianCutOptions = .init()) {
        self.options = options
    }

    public func extract(from image: PixelImage) async -> [PaletteColor] {
        await Self.extractAsync(from: image.pixels, options: options)
    }

    public static func extract(from pixels: [RGBColor], options: ModifiedMedianCutOptions = .init()) -> [PaletteColor] {
        let filtered = pixels.filter { $0.alpha >= options.minimumAlpha }
        guard !filtered.isEmpty else { return [] }
        let sampled = strideSample(filtered, limit: options.quality.maxSamples)

        let boxes = MedianCutQuantizer.quantize(pixels: sampled, targetBoxCount: options.colorCount)
        let total = boxes.reduce(0) { $0 + $1.population }
        guard total > 0 else { return [] }

        return boxes.map { box in
            let lab = ColorConverter.lab(from: box.rgb)
            return PaletteColor(rgb: box.rgb, lab: lab, population: box.population, percentage: Float(box.population) / Float(total))
        }.sorted { $0.population > $1.population }
    }

    public static func extractAsync(from pixels: [RGBColor], options: ModifiedMedianCutOptions = .init()) async -> [PaletteColor] {
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
