import Foundation

public struct FloodFillTechnique: PaletteExtractionTechnique {
    public var name: String { "Flood fill" }
    public var description: String { "Connected color regions, useful for big visual blocks" }
    public var options: FloodFillOptions

    public init(options: FloodFillOptions = .init()) {
        self.options = options
    }

    public func extract(from image: PixelImage) async -> [PaletteColor] {
        await Self.extractFloodFillAsync(from: image, options: options)
    }

    public static func extractFloodFill(from image: PixelImage, options: FloodFillOptions = .init()) -> [PaletteColor] {
        let width = image.width
        let height = image.height
        let pixels = image.pixels
        guard width > 0, height > 0, pixels.count == width * height else { return [] }

        let labs = pixels.map(ColorConverter.lab(from:))
        var visited = Array(repeating: false, count: pixels.count)
        var regions: [PaletteColor] = []
        let minimumRegionSize = max(1, Int(Float(pixels.count) * options.minimumRegionPercentage))

        for start in pixels.indices where !visited[start] {
            visited[start] = true
            guard pixels[start].alpha >= options.minimumAlpha else { continue }

            let seed = labs[start]
            var queue = [start]
            var cursor = 0
            var count = 0
            var sum = LabVector.zero

            while cursor < queue.count {
                let current = queue[cursor]
                cursor += 1
                count += 1
                sum += labs[current].vector

                let x = current % width
                let y = current / width
                let neighbors = [
                    x > 0 ? current - 1 : nil,
                    x + 1 < width ? current + 1 : nil,
                    y > 0 ? current - width : nil,
                    y + 1 < height ? current + width : nil
                ]

                for neighbor in neighbors.compactMap({ $0 }) where !visited[neighbor] {
                    visited[neighbor] = true
                    guard pixels[neighbor].alpha >= options.minimumAlpha else { continue }
                    if ColorClustering.distance(labs[neighbor], seed, method: options.deltaEMethod) <= options.similarityThreshold {
                        queue.append(neighbor)
                    }
                }
            }

            guard count >= minimumRegionSize else { continue }
            let lab = LabColor(vector: sum / Float(count))
            regions.append(PaletteColor(
                rgb: ColorConverter.rgb(from: lab),
                lab: lab,
                population: count,
                percentage: Float(count) / Float(pixels.count)
            ))
        }

        let merged = ColorClustering.mergeSimilar(regions.sorted { $0.population > $1.population }, threshold: options.mergeThreshold, method: options.deltaEMethod)
        return Array(merged.prefix(options.colorCount))
    }

    public static func extractFloodFillAsync(from image: PixelImage, options: FloodFillOptions = .init()) async -> [PaletteColor] {
        await Task.detached(priority: .userInitiated) {
            extractFloodFill(from: image, options: options)
        }.value
    }
}
