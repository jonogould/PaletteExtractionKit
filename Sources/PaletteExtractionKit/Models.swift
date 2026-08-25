import Foundation

public enum DeltaEMethod: Sendable {
    case deltaE76
    case deltaE2000
}

public enum PaletteQuality: Sendable {
    case fast
    case balanced
    case high

    public var maxSamples: Int {
        switch self {
        case .fast: 4_000
        case .balanced: 12_000
        case .high: 32_000
        }
    }

    public var maxDimension: Int {
        switch self {
        case .fast: 96
        case .balanced: 160
        case .high: 256
        }
    }
}

public struct FloodFillOptions: Sendable {
    public var colorCount: Int
    public var quality: PaletteQuality
    public var minimumAlpha: UInt8
    public var similarityThreshold: Float
    public var mergeThreshold: Float
    public var minimumRegionPercentage: Float
    public var deltaEMethod: DeltaEMethod

    public init(
        colorCount: Int = 4,
        quality: PaletteQuality = .balanced,
        minimumAlpha: UInt8 = 128,
        similarityThreshold: Float = 12,
        mergeThreshold: Float = 5,
        minimumRegionPercentage: Float = 0.003,
        deltaEMethod: DeltaEMethod = .deltaE2000
    ) {
        self.colorCount = max(1, colorCount)
        self.quality = quality
        self.minimumAlpha = minimumAlpha
        self.similarityThreshold = max(0, similarityThreshold)
        self.mergeThreshold = max(0, mergeThreshold)
        self.minimumRegionPercentage = max(0, minimumRegionPercentage)
        self.deltaEMethod = deltaEMethod
    }
}

public struct PixelImage: Sendable {
    public let pixels: [RGBColor]
    public let width: Int
    public let height: Int

    public init(pixels: [RGBColor], width: Int, height: Int) {
        self.pixels = pixels
        self.width = width
        self.height = height
    }
}

public struct PaletteColor: Sendable, Hashable {
    public let rgb: RGBColor
    public let lab: LabColor
    public let population: Int
    public let percentage: Float

    public var hex: String { rgb.hexString }
}

public struct PaletteOptions: Sendable {
    public var colorCount: Int
    public var maxSamples: Int
    public var maxIterations: Int
    public var convergenceThreshold: Float
    public var minimumAlpha: UInt8
    public var mergeThreshold: Float
    public var deltaEMethod: DeltaEMethod

    public init(
        colorCount: Int = 8,
        quality: PaletteQuality = .balanced,
        maxSamples: Int? = nil,
        maxIterations: Int = 30,
        convergenceThreshold: Float = 0.25,
        minimumAlpha: UInt8 = 128,
        mergeThreshold: Float = 4.0,
        deltaEMethod: DeltaEMethod = .deltaE2000
    ) {
        self.colorCount = max(1, colorCount)
        self.maxSamples = max(1, maxSamples ?? quality.maxSamples)
        self.maxIterations = max(1, maxIterations)
        self.convergenceThreshold = max(0, convergenceThreshold)
        self.minimumAlpha = minimumAlpha
        self.mergeThreshold = max(0, mergeThreshold)
        self.deltaEMethod = deltaEMethod
    }
}
