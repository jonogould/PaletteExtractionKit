import Foundation

public struct OctreeQuantizationOptions: Sendable {
    public var colorCount: Int
    public var quality: PaletteQuality
    public var minimumAlpha: UInt8

    public init(colorCount: Int = 4, quality: PaletteQuality = .balanced, minimumAlpha: UInt8 = 128) {
        self.colorCount = max(1, colorCount)
        self.quality = quality
        self.minimumAlpha = minimumAlpha
    }
}

/// Gervautz-Purgathofer octree color quantization — classic GIF-encoder lineage.
public struct OctreeQuantizationTechnique: PaletteExtractionTechnique {
    public var name: String { "Octree quantization" }
    public var description: String { "Octree color quantization" }
    public var options: OctreeQuantizationOptions

    public init(options: OctreeQuantizationOptions = .init()) {
        self.options = options
    }

    public func extract(from image: PixelImage) async -> [PaletteColor] {
        await Self.extractAsync(from: image.pixels, options: options)
    }

    public static func extract(from pixels: [RGBColor], options: OctreeQuantizationOptions = .init()) -> [PaletteColor] {
        let filtered = pixels.filter { $0.alpha >= options.minimumAlpha }
        guard !filtered.isEmpty else { return [] }
        let sampled = strideSample(filtered, limit: options.quality.maxSamples)
        return Octree.quantize(pixels: sampled, targetLeafCount: options.colorCount)
    }

    public static func extractAsync(from pixels: [RGBColor], options: OctreeQuantizationOptions = .init()) async -> [PaletteColor] {
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

/// Internal engine. Uses a mutable reference tree — built and torn down entirely inside
/// one synchronous call, so it never crosses an `await` and needs no `Sendable` conformance.
private enum Octree {
    private final class Node {
        var children: [Node?] = Array(repeating: nil, count: 8)
        var isLeaf = false
        var pixelCount = 0
        var sumR = 0
        var sumG = 0
        var sumB = 0
        let level: Int

        init(level: Int) {
            self.level = level
        }
    }

    static func quantize(pixels: [RGBColor], targetLeafCount: Int) -> [PaletteColor] {
        guard !pixels.isEmpty, targetLeafCount > 0 else { return [] }

        let root = Node(level: 0)
        var leafCount = 0

        for pixel in pixels {
            insert(pixel, node: root, depth: 0, leafCount: &leafCount)
        }

        while leafCount > targetLeafCount {
            guard reduceDeepest(root, leafCount: &leafCount) else { break }
        }

        var rawLeaves: [(rgb: RGBColor, population: Int)] = []
        collectLeaves(root, into: &rawLeaves)

        let total = rawLeaves.reduce(0) { $0 + $1.population }
        guard total > 0 else { return [] }

        return rawLeaves.map { entry in
            let lab = ColorConverter.lab(from: entry.rgb)
            return PaletteColor(rgb: entry.rgb, lab: lab, population: entry.population, percentage: Float(entry.population) / Float(total))
        }.sorted { $0.population > $1.population }
    }

    private static func insert(_ pixel: RGBColor, node: Node, depth: Int, leafCount: inout Int) {
        if depth == 8 {
            if !node.isLeaf {
                node.isLeaf = true
                leafCount += 1
            }
            node.pixelCount += 1
            node.sumR += Int(pixel.red)
            node.sumG += Int(pixel.green)
            node.sumB += Int(pixel.blue)
            return
        }

        let index = childIndex(pixel, depth: depth)
        let child: Node
        if let existing = node.children[index] {
            child = existing
        } else {
            child = Node(level: depth + 1)
            node.children[index] = child
        }
        insert(pixel, node: child, depth: depth + 1, leafCount: &leafCount)
    }

    private static func childIndex(_ pixel: RGBColor, depth: Int) -> Int {
        let shift = 7 - depth
        let r = (Int(pixel.red) >> shift) & 1
        let g = (Int(pixel.green) >> shift) & 1
        let b = (Int(pixel.blue) >> shift) & 1
        return (r << 2) | (g << 1) | b
    }

    /// Finds the deepest node whose existing children are all leaves, merges the one
    /// with the fewest total pixels among ties (sacrificing the least-significant cluster).
    private static func reduceDeepest(_ root: Node, leafCount: inout Int) -> Bool {
        var candidates: [Node] = []
        var deepestLevel = -1
        collectReducible(root, candidates: &candidates, deepestLevel: &deepestLevel)
        guard let target = candidates.min(by: { totalPixelCount($0) < totalPixelCount($1) }) else { return false }
        merge(target, leafCount: &leafCount)
        return true
    }

    private static func collectReducible(_ node: Node, candidates: inout [Node], deepestLevel: inout Int) {
        guard !node.isLeaf else { return }
        let existingChildren = node.children.compactMap { $0 }
        guard !existingChildren.isEmpty else { return }

        if existingChildren.allSatisfy({ $0.isLeaf }) {
            if node.level > deepestLevel {
                deepestLevel = node.level
                candidates = [node]
            } else if node.level == deepestLevel {
                candidates.append(node)
            }
        } else {
            for child in existingChildren {
                collectReducible(child, candidates: &candidates, deepestLevel: &deepestLevel)
            }
        }
    }

    private static func totalPixelCount(_ node: Node) -> Int {
        node.children.compactMap { $0 }.reduce(0) { $0 + $1.pixelCount }
    }

    private static func merge(_ node: Node, leafCount: inout Int) {
        var sumR = 0, sumG = 0, sumB = 0, count = 0
        var mergedChildren = 0
        for i in 0..<8 {
            if let child = node.children[i], child.isLeaf {
                sumR += child.sumR
                sumG += child.sumG
                sumB += child.sumB
                count += child.pixelCount
                node.children[i] = nil
                mergedChildren += 1
            }
        }
        node.sumR = sumR
        node.sumG = sumG
        node.sumB = sumB
        node.pixelCount = count
        node.isLeaf = true
        leafCount -= mergedChildren
        leafCount += 1
    }

    private static func collectLeaves(_ node: Node, into results: inout [(rgb: RGBColor, population: Int)]) {
        if node.isLeaf {
            guard node.pixelCount > 0 else { return }
            let rgb = RGBColor(
                red: UInt8(node.sumR / node.pixelCount),
                green: UInt8(node.sumG / node.pixelCount),
                blue: UInt8(node.sumB / node.pixelCount)
            )
            results.append((rgb, node.pixelCount))
            return
        }
        for child in node.children.compactMap({ $0 }) {
            collectLeaves(child, into: &results)
        }
    }
}
