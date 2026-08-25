import Testing
@testable import PaletteExtractionKit

@Test func rgbRoundTripProducesExpectedPrimaryColor() {
    let red = RGBColor(red: 255, green: 0, blue: 0)
    let lab = ColorConverter.lab(from: red)
    let result = ColorConverter.rgb(from: lab)
    #expect(abs(Int(result.red) - 255) <= 1)
    #expect(result.green <= 1)
    #expect(result.blue <= 1)
}

@Test func paletteFindsTwoDominantColors() {
    let pixels = Array(repeating: RGBColor(red: 255, green: 0, blue: 0), count: 100)
        + Array(repeating: RGBColor(red: 0, green: 0, blue: 255), count: 50)

    let palette = KMeansTechnique.extract(
        from: pixels,
        options: PaletteOptions(colorCount: 2, maxSamples: 1_000, mergeThreshold: 1)
    )

    #expect(palette.count == 2)
    #expect(palette[0].population == 100)
    #expect(palette[0].percentage > 0.6)
}

@Test func floodFillFindsConnectedRegions() async throws {
    let pixels = Array(repeating: RGBColor(red: 255, green: 0, blue: 0), count: 8)
        + Array(repeating: RGBColor(red: 0, green: 0, blue: 255), count: 8)
    let image = PixelImage(pixels: pixels, width: 4, height: 4)
    let palette = FloodFillTechnique.extractFloodFill(
        from: image,
        options: FloodFillOptions(colorCount: 2, minimumRegionPercentage: 0)
    )

    #expect(palette.count == 2)
}

@Test func extractManyRunsAllTechniquesAndPreservesOrder() async throws {
    let pixels = Array(repeating: RGBColor(red: 255, green: 0, blue: 0), count: 8)
        + Array(repeating: RGBColor(red: 0, green: 0, blue: 255), count: 8)
    let image = PixelImage(pixels: pixels, width: 4, height: 4)

    let results = await PaletteExtractor.extractMany(
        from: image,
        using: [
            KMeansTechnique(options: PaletteOptions(colorCount: 2)),
            FloodFillTechnique(options: FloodFillOptions(colorCount: 2, minimumRegionPercentage: 0)),
            MedianCutTechnique(options: MedianCutOptions(colorCount: 2)),
            ModifiedMedianCutTechnique(options: ModifiedMedianCutOptions(colorCount: 2)),
            WuQuantizationTechnique(options: WuQuantizationOptions(colorCount: 2)),
            OctreeQuantizationTechnique(options: OctreeQuantizationOptions(colorCount: 2)),
            HistogramTechnique(options: HistogramOptions(colorCount: 2)),
            AgglomerativeTechnique(options: AgglomerativeOptions(colorCount: 2)),
            AverageColorTechnique(),
            ScoredSwatchesTechnique()
        ]
    )

    #expect(results.map(\.name) == [
        "K-means", "Flood fill", "Median cut", "MMCQ", "Wu quantization",
        "Octree quantization", "Histogram", "Agglomerative", "Average color", "Scored swatches"
    ])
    #expect(results.allSatisfy { !$0.colors.isEmpty })
}

private struct SingleColorTechnique: PaletteExtractionTechnique {
    var name: String { "Single color" }

    func extract(from image: PixelImage) async -> [PaletteColor] {
        guard let first = image.pixels.first else { return [] }
        let lab = ColorConverter.lab(from: first)
        return [PaletteColor(rgb: first, lab: lab, population: image.pixels.count, percentage: 1)]
    }
}

@Test func customTechniqueConformsWithoutFrameworkChanges() async throws {
    let pixels = Array(repeating: RGBColor(red: 10, green: 20, blue: 30), count: 4)
    let image = PixelImage(pixels: pixels, width: 2, height: 2)

    let palette = await PaletteExtractor.extract(from: image, using: SingleColorTechnique())

    #expect(palette.count == 1)
    #expect(palette[0].rgb == RGBColor(red: 10, green: 20, blue: 30))
}
