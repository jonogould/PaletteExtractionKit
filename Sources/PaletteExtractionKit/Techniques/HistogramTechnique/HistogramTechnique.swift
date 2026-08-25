import Foundation

public struct HistogramOptions: Sendable {
    public var colorCount: Int
    public var quality: PaletteQuality
    public var minimumAlpha: UInt8
    public var bitsPerChannel: Int

    public init(colorCount: Int = 4, quality: PaletteQuality = .balanced, minimumAlpha: UInt8 = 128, bitsPerChannel: Int = 4) {
        self.colorCount = max(1, colorCount)
        self.quality = quality
        self.minimumAlpha = minimumAlpha
        self.bitsPerChannel = min(8, max(1, bitsPerChannel))
    }
}

/// Simplest possible technique: quantize, tally, take the top buckets. No perceptual
/// awareness at all — deliberate contrast with the Lab-based techniques in this package.
public struct HistogramTechnique: PaletteExtractionTechnique {
    public var name: String { "Histogram" }
    public var description: String { "Most-frequent quantized color buckets" }
    public var options: HistogramOptions

    public init(options: HistogramOptions = .init()) {
        self.options = options
    }

    public func extract(from image: PixelImage) async -> [PaletteColor] {
        await Self.extractAsync(from: image.pixels, options: options)
    }

    public static func extract(from pixels: [RGBColor], options: HistogramOptions = .init()) -> [PaletteColor] {
        let filtered = pixels.filter { $0.alpha >= options.minimumAlpha }
        guard !filtered.isEmpty else { return [] }
        let sampled = strideSample(filtered, limit: options.quality.maxSamples)

        let shift = 8 - options.bitsPerChannel
        var buckets: [Int: (count: Int, sumR: Int, sumG: Int, sumB: Int)] = [:]

        for pixel in sampled {
            let r = Int(pixel.red) >> shift
            let g = Int(pixel.green) >> shift
            let b = Int(pixel.blue) >> shift
            let levels = 1 << options.bitsPerChannel
            let key = r * levels * levels + g * levels + b
            var bucket = buckets[key] ?? (0, 0, 0, 0)
            bucket.count += 1
            bucket.sumR += Int(pixel.red)
            bucket.sumG += Int(pixel.green)
            bucket.sumB += Int(pixel.blue)
            buckets[key] = bucket
        }

        let total = sampled.count
        let top = buckets.values.sorted { $0.count > $1.count }.prefix(options.colorCount)

        return top.map { bucket in
            let rgb = RGBColor(red: UInt8(bucket.sumR / bucket.count), green: UInt8(bucket.sumG / bucket.count), blue: UInt8(bucket.sumB / bucket.count))
            let lab = ColorConverter.lab(from: rgb)
            return PaletteColor(rgb: rgb, lab: lab, population: bucket.count, percentage: Float(bucket.count) / Float(total))
        }
    }

    public static func extractAsync(from pixels: [RGBColor], options: HistogramOptions = .init()) async -> [PaletteColor] {
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
