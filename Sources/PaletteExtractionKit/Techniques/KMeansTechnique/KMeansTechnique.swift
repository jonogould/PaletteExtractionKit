import Foundation

public struct KMeansTechnique: PaletteExtractionTechnique {
    public var name: String { "K-means" }
    public var description: String { "Perceptual clustering across the whole image" }
    public var options: PaletteOptions

    public init(options: PaletteOptions = .init()) {
        self.options = options
    }

    public func extract(from image: PixelImage) async -> [PaletteColor] {
        await Self.extractAsync(from: image.pixels, options: options)
    }

    public static func extract(from pixels: [RGBColor], options: PaletteOptions = .init()) -> [PaletteColor] {
        let filtered = pixels.filter { $0.alpha >= options.minimumAlpha }
        guard !filtered.isEmpty else { return [] }

        let sampled = strideSample(filtered, limit: options.maxSamples)
        let labs = sampled.map(ColorConverter.lab(from:))
        let k = min(options.colorCount, labs.count)
        var centroids = initialCentroids(from: labs, k: k, method: options.deltaEMethod)
        var assignments = Array(repeating: 0, count: labs.count)

        for _ in 0..<options.maxIterations {
            for index in labs.indices {
                assignments[index] = nearestCentroid(to: labs[index], centroids: centroids, method: options.deltaEMethod)
            }

            var sums = Array(repeating: LabVector.zero, count: k)
            var counts = Array(repeating: 0, count: k)
            for (index, lab) in labs.enumerated() {
                let cluster = assignments[index]
                sums[cluster] += lab.vector
                counts[cluster] += 1
            }

            var totalShift: Float = 0
            for index in 0..<k where counts[index] > 0 {
                let updated = LabColor(vector: sums[index] / Float(counts[index]))
                totalShift += ColorClustering.distance(centroids[index], updated, method: options.deltaEMethod)
                centroids[index] = updated
            }

            if totalShift / Float(k) <= options.convergenceThreshold { break }
        }

        var counts = Array(repeating: 0, count: k)
        for lab in labs {
            counts[nearestCentroid(to: lab, centroids: centroids, method: options.deltaEMethod)] += 1
        }

        let raw = centroids.indices
            .filter { counts[$0] > 0 }
            .map { index in
                PaletteColor(
                    rgb: ColorConverter.rgb(from: centroids[index]),
                    lab: centroids[index],
                    population: counts[index],
                    percentage: Float(counts[index]) / Float(labs.count)
                )
            }
            .sorted { $0.population > $1.population }

        return Array(ColorClustering.mergeSimilar(raw, threshold: options.mergeThreshold, method: options.deltaEMethod).prefix(options.colorCount))
    }

    public static func extractAsync(from pixels: [RGBColor], options: PaletteOptions = .init()) async -> [PaletteColor] {
        await Task.detached(priority: .userInitiated) {
            extract(from: pixels, options: options)
        }.value
    }

    private static func strideSample<T>(_ input: [T], limit: Int) -> [T] {
        guard input.count > limit else { return input }
        let step = Double(input.count) / Double(limit)
        return (0..<limit).map { input[Int(Double($0) * step)] }
    }

    private static func initialCentroids(from labs: [LabColor], k: Int, method: DeltaEMethod) -> [LabColor] {
        guard let first = labs.first else { return [] }
        var centroids = [first]
        while centroids.count < k {
            let candidate = labs.max { left, right in
                minDistance(from: left, to: centroids, method: method) < minDistance(from: right, to: centroids, method: method)
            } ?? labs[centroids.count % labs.count]
            centroids.append(candidate)
        }
        return centroids
    }

    private static func nearestCentroid(to lab: LabColor, centroids: [LabColor], method: DeltaEMethod) -> Int {
        var bestIndex = 0
        var bestDistance = Float.greatestFiniteMagnitude
        for (index, centroid) in centroids.enumerated() {
            let d = ColorClustering.distance(lab, centroid, method: method)
            if d < bestDistance {
                bestDistance = d
                bestIndex = index
            }
        }
        return bestIndex
    }

    private static func minDistance(from lab: LabColor, to centroids: [LabColor], method: DeltaEMethod) -> Float {
        centroids.map { ColorClustering.distance(lab, $0, method: method) }.min() ?? 0
    }
}
