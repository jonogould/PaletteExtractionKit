import Testing
@testable import PaletteExtractionKit

#if canImport(AppKit)
import AppKit

@Test func imagePipelineProducesDistinctSwatches() async throws {
    let size = CGSize(width: 40, height: 40)
    let image = NSImage(size: size)
    image.lockFocus()
    NSColor(red: 1, green: 0, blue: 0, alpha: 1).setFill()
    NSRect(x: 0, y: 0, width: 20, height: 40).fill()
    NSColor(red: 0, green: 0, blue: 1, alpha: 1).setFill()
    NSRect(x: 20, y: 0, width: 20, height: 40).fill()
    image.unlockFocus()

    let kMeans = try await image.labPalette(quality: .fast, using: KMeansTechnique(options: .init(colorCount: 2)))
    let floodFill = try await image.labPalette(quality: .fast, using: FloodFillTechnique(options: .init(colorCount: 2)))

    #expect(kMeans.count == 2)
    #expect(Set(kMeans.map(\.hex)).count == 2)

    #expect(floodFill.count == 2)
    #expect(Set(floodFill.map(\.hex)).count == 2)
}
#endif
