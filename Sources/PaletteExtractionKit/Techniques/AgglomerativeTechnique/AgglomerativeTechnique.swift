import Foundation

public struct AgglomerativeOptions: Sendable {
    public var colorCount: Int
    public var quality: PaletteQuality
    public var minimumAlpha: UInt8
    public var maxClusters: Int
    public var deltaEMethod: DeltaEMethod

    public init(
        colorCount: Int = 4,
        quality: PaletteQuality = .balanced,
        minimumAlpha: UInt8 = 128,
        maxClusters: Int = 256,
        deltaEMethod: DeltaEMethod = .deltaE2000
    ) {
        self.colorCount = max(1, colorCount)
        self.quality = quality
        self.minimumAlpha = minimumAlpha
        self.maxClusters = max(colorCount, maxClusters)
        self.deltaEMethod = deltaEMethod
    }
}

/// Bottom-up hierarchical merge — the opposite direction from K-means (which starts with
/// K clusters and converges) or median-cut (which starts with 1 box and splits).
public struct AgglomerativeTechnique: PaletteExtractionTechnique {
    public var name: String { "Agglomerative" }
    public var description: String { "Bottom-up nearest-pair merging in L*a*b* space" }
    public var options: AgglomerativeOptions

    public init(options: AgglomerativeOptions = .init()) {
        self.options = options
    }

    public func extract(from image: PixelImage) async -> [PaletteColor] {
        await Self.extractAsync(from: image.pixels, options: options)
    }

    public static func extract(from pixels: [RGBColor], options: AgglomerativeOptions = .init()) -> [PaletteColor] {
        let filtered = pixels.filter { $0.alpha >= options.minimumAlpha }
        guard !filtered.isEmpty else { return [] }
        let sampled = strideSample(filtered, limit: options.quality.maxSamples)

        var clusters = preBucket(sampled, maxClusters: options.maxClusters)
        let total = clusters.reduce(0) { $0 + $1.population }
        guard total > 0 else { return [] }

        while clusters.count > options.colorCount {
            guard let (i, j) = nearestPair(clusters, method: options.deltaEMethod) else { break }
            let merged = merge(clusters[i], clusters[j])
            // Remove the higher index first so the lower index stays valid.
            clusters.remove(at: max(i, j))
            clusters.remove(at: min(i, j))
            clusters.append(merged)
        }

        return clusters.map { cluster in
            PaletteColor(rgb: cluster.rgb, lab: cluster.lab, population: cluster.population, percentage: Float(cluster.population) / Float(total))
        }.sorted { $0.population > $1.population }
    }

    public static func extractAsync(from pixels: [RGBColor], options: AgglomerativeOptions = .init()) async -> [PaletteColor] {
        await Task.detached(priority: .userInitiated) {
            extract(from: pixels, options: options)
        }.value
    }

    private struct Cluster {
        var rgb: RGBColor
        var lab: LabColor
        var population: Int
    }

    /// Coarse histogram pre-bucket, independent of `HistogramTechnique` — this bucketing
    /// is trivial enough that sharing it isn't worth coupling two independent techniques.
    private static func preBucket(_ pixels: [RGBColor], maxClusters: Int) -> [Cluster] {
        var bitsPerChannel = 5
        while bitsPerChannel > 1 {
            let levels = 1 << bitsPerChannel
            if levels * levels * levels <= maxClusters * 4 { break }
            bitsPerChannel -= 1
        }
        let shift = 8 - bitsPerChannel
        let levels = 1 << bitsPerChannel

        var buckets: [Int: (count: Int, sumR: Int, sumG: Int, sumB: Int)] = [:]
        for pixel in pixels {
            let r = Int(pixel.red) >> shift
            let g = Int(pixel.green) >> shift
            let b = Int(pixel.blue) >> shift
            let key = r * levels * levels + g * levels + b
            var bucket = buckets[key] ?? (0, 0, 0, 0)
            bucket.count += 1
            bucket.sumR += Int(pixel.red)
            bucket.sumG += Int(pixel.green)
            bucket.sumB += Int(pixel.blue)
            buckets[key] = bucket
        }

        let sorted = buckets.values.sorted { $0.count > $1.count }.prefix(maxClusters)
        return sorted.map { bucket in
            let rgb = RGBColor(red: UInt8(bucket.sumR / bucket.count), green: UInt8(bucket.sumG / bucket.count), blue: UInt8(bucket.sumB / bucket.count))
            return Cluster(rgb: rgb, lab: ColorConverter.lab(from: rgb), population: bucket.count)
        }
    }

    private static func nearestPair(_ clusters: [Cluster], method: DeltaEMethod) -> (Int, Int)? {
        guard clusters.count > 1 else { return nil }
        var best: (Int, Int)?
        var bestDistance = Float.greatestFiniteMagnitude
        for i in 0..<clusters.count {
            for j in (i + 1)..<clusters.count {
                let d = ColorClustering.distance(clusters[i].lab, clusters[j].lab, method: method)
                if d < bestDistance {
                    bestDistance = d
                    best = (i, j)
                }
            }
        }
        return best
    }

    private static func merge(_ a: Cluster, _ b: Cluster) -> Cluster {
        let total = a.population + b.population
        let vector = (a.lab.vector * Float(a.population) + b.lab.vector * Float(b.population)) / Float(total)
        let lab = LabColor(vector: vector)
        return Cluster(rgb: ColorConverter.rgb(from: lab), lab: lab, population: total)
    }

    private static func strideSample<T>(_ input: [T], limit: Int) -> [T] {
        guard input.count > limit else { return input }
        let step = Double(input.count) / Double(limit)
        return (0..<limit).map { input[Int(Double($0) * step)] }
    }
}
