import Foundation

/// Shared MMCQ-style box-splitting quantizer, used by `ModifiedMedianCutTechnique` and
/// `ScoredSwatchesTechnique`. Not a `PaletteExtractionTechnique` itself — an internal engine.
enum MedianCutQuantizer {
    struct VBox: Sendable {
        let rgb: RGBColor
        let population: Int
    }

    private static let levels = 32
    private static let shift = 3 // 8 - 5 bits per channel

    private struct Bucket {
        var count = 0
        var sumR = 0
        var sumG = 0
        var sumB = 0
    }

    private struct Box {
        var minBound: [Int] // [rMin, gMin, bMin], tightened to actual occupied extent
        var maxBound: [Int] // [rMax, gMax, bMax], tightened to actual occupied extent
        var population: Int
    }

    static func quantize(pixels: [RGBColor], targetBoxCount: Int) -> [VBox] {
        guard !pixels.isEmpty, targetBoxCount > 0 else { return [] }

        var histogram = [Bucket](repeating: Bucket(), count: levels * levels * levels)
        for pixel in pixels {
            let r = Int(pixel.red) >> shift
            let g = Int(pixel.green) >> shift
            let b = Int(pixel.blue) >> shift
            let idx = flatIndex(r, g, b)
            histogram[idx].count += 1
            histogram[idx].sumR += Int(pixel.red)
            histogram[idx].sumG += Int(pixel.green)
            histogram[idx].sumB += Int(pixel.blue)
        }

        guard let initialBox = makeBox(minBound: [0, 0, 0], maxBound: [levels - 1, levels - 1, levels - 1], histogram: histogram) else {
            return []
        }

        var boxes = [initialBox]

        while boxes.count < targetBoxCount {
            var bestIndex: Int?
            var bestScore = -1
            for (i, box) in boxes.enumerated() {
                guard isSplittable(box) else { continue }
                let score = box.population * volume(box)
                if score > bestScore {
                    bestScore = score
                    bestIndex = i
                }
            }
            guard let splitIndex = bestIndex, let children = split(boxes[splitIndex], histogram: histogram) else { break }
            boxes.remove(at: splitIndex)
            boxes.append(children.0)
            boxes.append(children.1)
        }

        return boxes.compactMap { box -> VBox? in
            var sumR = 0, sumG = 0, sumB = 0, count = 0
            for r in box.minBound[0]...box.maxBound[0] {
                for g in box.minBound[1]...box.maxBound[1] {
                    for b in box.minBound[2]...box.maxBound[2] {
                        let bucket = histogram[flatIndex(r, g, b)]
                        sumR += bucket.sumR
                        sumG += bucket.sumG
                        sumB += bucket.sumB
                        count += bucket.count
                    }
                }
            }
            guard count > 0 else { return nil }
            let rgb = RGBColor(red: UInt8(sumR / count), green: UInt8(sumG / count), blue: UInt8(sumB / count))
            return VBox(rgb: rgb, population: count)
        }
    }

    private static func isSplittable(_ box: Box) -> Bool {
        volume(box) > 1 && box.population > 1
    }

    private static func volume(_ box: Box) -> Int {
        (box.maxBound[0] - box.minBound[0] + 1) * (box.maxBound[1] - box.minBound[1] + 1) * (box.maxBound[2] - box.minBound[2] + 1)
    }

    private static func split(_ box: Box, histogram: [Bucket]) -> (Box, Box)? {
        let ranges = [
            box.maxBound[0] - box.minBound[0],
            box.maxBound[1] - box.minBound[1],
            box.maxBound[2] - box.minBound[2]
        ]
        guard let maxRange = ranges.max(), maxRange > 0 else { return nil }
        let axis = ranges.firstIndex(of: maxRange)!

        let half = (box.population + 1) / 2
        var cumulative = 0
        var cutCoordinate = box.minBound[axis]

        for coordinate in box.minBound[axis]..<box.maxBound[axis] {
            var sliceMin = box.minBound
            var sliceMax = box.maxBound
            sliceMin[axis] = coordinate
            sliceMax[axis] = coordinate
            cumulative += regionPopulation(minBound: sliceMin, maxBound: sliceMax, histogram: histogram)
            cutCoordinate = coordinate
            if cumulative >= half { break }
        }

        var maxA = box.maxBound
        maxA[axis] = cutCoordinate

        var minB = box.minBound
        minB[axis] = cutCoordinate + 1

        guard let boxA = makeBox(minBound: box.minBound, maxBound: maxA, histogram: histogram),
              let boxB = makeBox(minBound: minB, maxBound: box.maxBound, histogram: histogram) else {
            return nil
        }
        return (boxA, boxB)
    }

    /// Scans the given region once, tightening bounds to the actual occupied extent and
    /// computing total population. Returns nil if the region contains no populated buckets.
    private static func makeBox(minBound: [Int], maxBound: [Int], histogram: [Bucket]) -> Box? {
        var tightMin = maxBound
        var tightMax = minBound
        var population = 0
        for r in minBound[0]...maxBound[0] {
            for g in minBound[1]...maxBound[1] {
                for b in minBound[2]...maxBound[2] {
                    let bucket = histogram[flatIndex(r, g, b)]
                    guard bucket.count > 0 else { continue }
                    population += bucket.count
                    tightMin[0] = min(tightMin[0], r); tightMax[0] = max(tightMax[0], r)
                    tightMin[1] = min(tightMin[1], g); tightMax[1] = max(tightMax[1], g)
                    tightMin[2] = min(tightMin[2], b); tightMax[2] = max(tightMax[2], b)
                }
            }
        }
        guard population > 0 else { return nil }
        return Box(minBound: tightMin, maxBound: tightMax, population: population)
    }

    private static func regionPopulation(minBound: [Int], maxBound: [Int], histogram: [Bucket]) -> Int {
        var total = 0
        for r in minBound[0]...maxBound[0] {
            for g in minBound[1]...maxBound[1] {
                for b in minBound[2]...maxBound[2] {
                    total += histogram[flatIndex(r, g, b)].count
                }
            }
        }
        return total
    }

    private static func flatIndex(_ r: Int, _ g: Int, _ b: Int) -> Int {
        r * levels * levels + g * levels + b
    }
}
