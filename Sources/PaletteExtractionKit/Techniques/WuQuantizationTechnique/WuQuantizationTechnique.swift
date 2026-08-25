import Foundation

public struct WuQuantizationOptions: Sendable {
    public var colorCount: Int
    public var quality: PaletteQuality
    public var minimumAlpha: UInt8

    public init(colorCount: Int = 4, quality: PaletteQuality = .balanced, minimumAlpha: UInt8 = 128) {
        self.colorCount = max(1, colorCount)
        self.quality = quality
        self.minimumAlpha = minimumAlpha
    }
}

/// Xiaolin Wu's variance-minimizing color quantizer — the algorithm behind ImageMagick's
/// and .NET's default palette reduction.
public struct WuQuantizationTechnique: PaletteExtractionTechnique {
    public var name: String { "Wu quantization" }
    public var description: String { "Variance-minimizing quantizer, ImageMagick's default" }
    public var options: WuQuantizationOptions

    public init(options: WuQuantizationOptions = .init()) {
        self.options = options
    }

    public func extract(from image: PixelImage) async -> [PaletteColor] {
        await Self.extractAsync(from: image.pixels, options: options)
    }

    public static func extract(from pixels: [RGBColor], options: WuQuantizationOptions = .init()) -> [PaletteColor] {
        let filtered = pixels.filter { $0.alpha >= options.minimumAlpha }
        guard !filtered.isEmpty else { return [] }
        let sampled = strideSample(filtered, limit: options.quality.maxSamples)
        return WuQuantizer.quantize(pixels: sampled, targetBoxCount: options.colorCount)
    }

    public static func extractAsync(from pixels: [RGBColor], options: WuQuantizationOptions = .init()) async -> [PaletteColor] {
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

/// Internal engine. 3D-moment box splitting isn't shared by anything else, so this stays
/// private to this file rather than living alongside `MedianCutQuantizer`.
private enum WuQuantizer {
    private static let size = 33 // 32 quantization levels (5 bits/channel) + 1 zero boundary

    private struct Moments {
        var weight: [Double]
        var momentR: [Double]
        var momentG: [Double]
        var momentB: [Double]
        var momentSq: [Double]

        init(count: Int) {
            weight = [Double](repeating: 0, count: count)
            momentR = [Double](repeating: 0, count: count)
            momentG = [Double](repeating: 0, count: count)
            momentB = [Double](repeating: 0, count: count)
            momentSq = [Double](repeating: 0, count: count)
        }
    }

    private struct Box {
        var r0: Int, r1: Int
        var g0: Int, g1: Int
        var b0: Int, b1: Int
    }

    static func quantize(pixels: [RGBColor], targetBoxCount: Int) -> [PaletteColor] {
        guard !pixels.isEmpty, targetBoxCount > 0 else { return [] }

        var moments = Moments(count: size * size * size)
        for pixel in pixels {
            let r = (Int(pixel.red) >> 3) + 1
            let g = (Int(pixel.green) >> 3) + 1
            let b = (Int(pixel.blue) >> 3) + 1
            let idx = flatIndex(r, g, b)
            let red = Double(pixel.red), green = Double(pixel.green), blue = Double(pixel.blue)
            moments.weight[idx] += 1
            moments.momentR[idx] += red
            moments.momentG[idx] += green
            moments.momentB[idx] += blue
            moments.momentSq[idx] += red * red + green * green + blue * blue
        }

        accumulate(&moments)

        var boxes = [Box(r0: 0, r1: 32, g0: 0, g1: 32, b0: 0, b1: 32)]

        while boxes.count < targetBoxCount {
            guard let splitIndex = bestBoxToSplit(boxes, moments: moments),
                  let children = split(boxes[splitIndex], moments: moments) else {
                break
            }
            boxes.remove(at: splitIndex)
            boxes.append(children.0)
            boxes.append(children.1)
        }

        let rawBoxes: [(rgb: RGBColor, population: Int)] = boxes.compactMap { box in
            let weight = volumeMoment(box, table: moments.weight)
            guard weight > 0 else { return nil }
            let r = volumeMoment(box, table: moments.momentR) / weight
            let g = volumeMoment(box, table: moments.momentG) / weight
            let b = volumeMoment(box, table: moments.momentB) / weight
            let rgb = RGBColor(red: UInt8(r.rounded()), green: UInt8(g.rounded()), blue: UInt8(b.rounded()))
            return (rgb, Int(weight))
        }

        let total = rawBoxes.reduce(0) { $0 + $1.population }
        guard total > 0 else { return [] }

        return rawBoxes.map { entry in
            let lab = ColorConverter.lab(from: entry.rgb)
            return PaletteColor(rgb: entry.rgb, lab: lab, population: entry.population, percentage: Float(entry.population) / Float(total))
        }.sorted { $0.population > $1.population }
    }

    private static func accumulate(_ moments: inout Moments) {
        accumulateAxis(&moments.weight)
        accumulateAxis(&moments.momentR)
        accumulateAxis(&moments.momentG)
        accumulateAxis(&moments.momentB)
        accumulateAxis(&moments.momentSq)
    }

    /// Builds a full 3D cumulative (summed-volume) table in place, one axis at a time.
    private static func accumulateAxis(_ table: inout [Double]) {
        for g in 0..<size {
            for b in 0..<size {
                for r in 1..<size {
                    table[flatIndex(r, g, b)] += table[flatIndex(r - 1, g, b)]
                }
            }
        }
        for r in 0..<size {
            for b in 0..<size {
                for g in 1..<size {
                    table[flatIndex(r, g, b)] += table[flatIndex(r, g - 1, b)]
                }
            }
        }
        for r in 0..<size {
            for g in 0..<size {
                for b in 1..<size {
                    table[flatIndex(r, g, b)] += table[flatIndex(r, g, b - 1)]
                }
            }
        }
    }

    /// 8-corner inclusion-exclusion lookup on a cumulative table — the standard 3D
    /// summed-volume-table query, restricted to the box's (exclusive-low, inclusive-high) bounds.
    private static func volumeMoment(_ box: Box, table: [Double]) -> Double {
        table[flatIndex(box.r1, box.g1, box.b1)]
            - table[flatIndex(box.r1, box.g1, box.b0)]
            - table[flatIndex(box.r1, box.g0, box.b1)]
            + table[flatIndex(box.r1, box.g0, box.b0)]
            - table[flatIndex(box.r0, box.g1, box.b1)]
            + table[flatIndex(box.r0, box.g1, box.b0)]
            + table[flatIndex(box.r0, box.g0, box.b1)]
            - table[flatIndex(box.r0, box.g0, box.b0)]
    }

    private static func variance(_ box: Box, moments: Moments) -> Double {
        let weight = volumeMoment(box, table: moments.weight)
        guard weight > 0 else { return 0 }
        let r = volumeMoment(box, table: moments.momentR)
        let g = volumeMoment(box, table: moments.momentG)
        let b = volumeMoment(box, table: moments.momentB)
        let sq = volumeMoment(box, table: moments.momentSq)
        return sq - (r * r + g * g + b * b) / weight
    }

    private static func isSplittable(_ box: Box) -> Bool {
        (box.r1 - box.r0) > 1 || (box.g1 - box.g0) > 1 || (box.b1 - box.b0) > 1
    }

    private static func bestBoxToSplit(_ boxes: [Box], moments: Moments) -> Int? {
        var bestIndex: Int?
        var bestVariance = -Double.infinity
        for (i, box) in boxes.enumerated() {
            guard isSplittable(box) else { continue }
            let v = variance(box, moments: moments)
            if v > bestVariance {
                bestVariance = v
                bestIndex = i
            }
        }
        return bestIndex
    }

    /// Tries every interior cut on every axis, keeps whichever maximizes
    /// (moment²/weight) summed across the two children — equivalent to minimizing
    /// total post-split variance, since the parent's momentSq term is fixed either way.
    private static func split(_ box: Box, moments: Moments) -> (Box, Box)? {
        var bestScore = -Double.infinity
        var bestAxis = -1
        var bestCut = -1

        let axisRanges: [(axis: Int, lo: Int, hi: Int)] = [
            (0, box.r0, box.r1),
            (1, box.g0, box.g1),
            (2, box.b0, box.b1)
        ]

        for (axis, lo, hi) in axisRanges where hi - lo > 1 {
            for cut in (lo + 1)..<hi {
                guard let score = splitScore(box: box, axis: axis, cut: cut, moments: moments) else { continue }
                if score > bestScore {
                    bestScore = score
                    bestAxis = axis
                    bestCut = cut
                }
            }
        }

        guard bestAxis >= 0 else { return nil }

        var boxA = box
        var boxB = box
        switch bestAxis {
        case 0: boxA.r1 = bestCut; boxB.r0 = bestCut
        case 1: boxA.g1 = bestCut; boxB.g0 = bestCut
        default: boxA.b1 = bestCut; boxB.b0 = bestCut
        }
        return (boxA, boxB)
    }

    private static func splitScore(box: Box, axis: Int, cut: Int, moments: Moments) -> Double? {
        var boxA = box
        var boxB = box
        switch axis {
        case 0: boxA.r1 = cut; boxB.r0 = cut
        case 1: boxA.g1 = cut; boxB.g0 = cut
        default: boxA.b1 = cut; boxB.b0 = cut
        }

        let w1 = volumeMoment(boxA, table: moments.weight)
        let w2 = volumeMoment(boxB, table: moments.weight)
        guard w1 > 0, w2 > 0 else { return nil }

        let r1 = volumeMoment(boxA, table: moments.momentR)
        let g1 = volumeMoment(boxA, table: moments.momentG)
        let b1 = volumeMoment(boxA, table: moments.momentB)
        let r2 = volumeMoment(boxB, table: moments.momentR)
        let g2 = volumeMoment(boxB, table: moments.momentG)
        let b2 = volumeMoment(boxB, table: moments.momentB)

        return (r1 * r1 + g1 * g1 + b1 * b1) / w1 + (r2 * r2 + g2 * g2 + b2 * b2) / w2
    }

    private static func flatIndex(_ r: Int, _ g: Int, _ b: Int) -> Int {
        r * size * size + g * size + b
    }
}
