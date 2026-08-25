import Foundation

public enum PaletteExtractor {
    public static func extract(from image: PixelImage, using technique: some PaletteExtractionTechnique) async -> [PaletteColor] {
        await technique.extract(from: image)
    }

    public static func extractMany(from image: PixelImage, using techniques: [any PaletteExtractionTechnique]) async -> [ExtractedPalette] {
        await withTaskGroup(of: ExtractedPalette.self) { group in
            for (index, technique) in techniques.enumerated() {
                group.addTask {
                    ExtractedPalette(
                        id: index,
                        name: technique.name,
                        description: technique.description,
                        colors: await technique.extract(from: image)
                    )
                }
            }

            var results = [ExtractedPalette?](repeating: nil, count: techniques.count)
            for await result in group {
                results[result.id] = result
            }
            return results.compactMap { $0 }
        }
    }
}
