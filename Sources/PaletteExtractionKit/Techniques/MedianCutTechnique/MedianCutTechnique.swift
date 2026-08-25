import Foundation

public struct MedianCutOptions: Sendable {
    public var colorCount: Int
    public var quality: PaletteQuality
    public var minimumAlpha: UInt8

    public init(colorCount: Int = 4, quality: PaletteQuality = .balanced, minimumAlpha: UInt8 = 128) {
        self.colorCount = max(1, colorCount)
        self.quality = quality
        self.minimumAlpha = minimumAlpha
    }
}

public struct MedianCutTechnique: PaletteExtractionTechnique {
    public var name: String { "Median cut" }
    public var description: String { "Classic recursive bounding-box split in RGB space" }
    public var options: MedianCutOptions

    public init(options: MedianCutOptions = .init()) {
        self.options = options
    }

    public func extract(from image: PixelImage) async -> [PaletteColor] {
        await Self.extractAsync(from: image.pixels, options: options)
    }

    public static func extract(from pixels: [RGBColor], options: MedianCutOptions = .init()) -> [PaletteColor] {
        let filtered = pixels.filter { $0.alpha >= options.minimumAlpha }
        guard !filtered.isEmpty else { return [] }
        let sampled = strideSample(filtered, limit: options.quality.maxSamples)

        var boxes: [[RGBColor]] = [sampled]

        while boxes.count < options.colorCount {
            guard let splitIndex = largestRangeBoxIndex(boxes), let halves = split(boxes[splitIndex]) else { break }
            boxes.remove(at: splitIndex)
            boxes.append(halves.0)
            boxes.append(halves.1)
        }

        let total = boxes.reduce(0) { $0 + $1.count }
        guard total > 0 else { return [] }

        return boxes.compactMap { box -> PaletteColor? in
            guard !box.isEmpty else { return nil }
            let rgb = average(box)
            let lab = ColorConverter.lab(from: rgb)
            return PaletteColor(rgb: rgb, lab: lab, population: box.count, percentage: Float(box.count) / Float(total))
        }.sorted { $0.population > $1.population }
    }

    public static func extractAsync(from pixels: [RGBColor], options: MedianCutOptions = .init()) async -> [PaletteColor] {
        await Task.detached(priority: .userInitiated) {
            extract(from: pixels, options: options)
        }.value
    }

    private static func largestRangeBoxIndex(_ boxes: [[RGBColor]]) -> Int? {
        var bestIndex: Int?
        var bestRange: UInt8 = 0
        for (index, box) in boxes.enumerated() {
            guard box.count > 1 else { continue }
            let range = channelRanges(box).max() ?? 0
            if bestIndex == nil || range > bestRange {
                bestIndex = index
                bestRange = range
            }
        }
        return bestRange > 0 ? bestIndex : nil
    }

    private static func channelRanges(_ box: [RGBColor]) -> [UInt8] {
        var minR = UInt8.max, maxR: UInt8 = 0
        var minG = UInt8.max, maxG: UInt8 = 0
        var minB = UInt8.max, maxB: UInt8 = 0
        for color in box {
            minR = min(minR, color.red); maxR = max(maxR, color.red)
            minG = min(minG, color.green); maxG = max(maxG, color.green)
            minB = min(minB, color.blue); maxB = max(maxB, color.blue)
        }
        return [maxR - minR, maxG - minG, maxB - minB]
    }

    private static func split(_ box: [RGBColor]) -> ([RGBColor], [RGBColor])? {
        guard box.count > 1 else { return nil }
        let ranges = channelRanges(box)
        guard let maxRange = ranges.max(), maxRange > 0 else { return nil }
        let axis = ranges.firstIndex(of: maxRange) ?? 0

        let sorted = box.sorted { channelValue($0, axis: axis) < channelValue($1, axis: axis) }
        let mid = sorted.count / 2
        return (Array(sorted[..<mid]), Array(sorted[mid...]))
    }

    private static func channelValue(_ color: RGBColor, axis: Int) -> UInt8 {
        switch axis {
        case 0: return color.red
        case 1: return color.green
        default: return color.blue
        }
    }

    private static func average(_ box: [RGBColor]) -> RGBColor {
        var sumR = 0, sumG = 0, sumB = 0, sumA = 0
        for color in box {
            sumR += Int(color.red)
            sumG += Int(color.green)
            sumB += Int(color.blue)
            sumA += Int(color.alpha)
        }
        let count = box.count
        return RGBColor(
            red: UInt8(sumR / count),
            green: UInt8(sumG / count),
            blue: UInt8(sumB / count),
            alpha: UInt8(sumA / count)
        )
    }

    private static func strideSample<T>(_ input: [T], limit: Int) -> [T] {
        guard input.count > limit else { return input }
        let step = Double(input.count) / Double(limit)
        return (0..<limit).map { input[Int(Double($0) * step)] }
    }
}
