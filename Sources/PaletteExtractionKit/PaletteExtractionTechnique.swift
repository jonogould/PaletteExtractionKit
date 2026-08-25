import Foundation

public protocol PaletteExtractionTechnique: Sendable {
    var name: String { get }
    var description: String { get }
    func extract(from image: PixelImage) async -> [PaletteColor]
}

public extension PaletteExtractionTechnique {
    var description: String { "" }
}

public struct ExtractedPalette: Sendable, Identifiable {
    public let id: Int
    public let name: String
    public let description: String
    public let colors: [PaletteColor]
}
