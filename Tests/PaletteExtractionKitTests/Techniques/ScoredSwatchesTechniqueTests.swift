import Testing
@testable import PaletteExtractionKit

@Test func scoredSwatchesFindsVibrantAndMutedRegions() {
    // Pure red: saturation 1.0, lightness 0.5 — dead-center Vibrant target.
    // Muted gray-brown: low saturation, mid lightness — dead-center Muted target.
    let pixels = Array(repeating: RGBColor(red: 255, green: 0, blue: 0), count: 200)
        + Array(repeating: RGBColor(red: 150, green: 140, blue: 130), count: 200)

    let palette = ScoredSwatchesTechnique.extract(from: pixels)

    #expect(!palette.isEmpty)
    let saturations = palette.map { ColorConverter.hsl(from: $0.rgb).saturation }
    #expect(saturations.contains { $0 >= 0.35 })
    #expect(saturations.contains { $0 <= 0.40 })
}

@Test func scoredSwatchesOmitsUnqualifyingCategories() {
    // Flat mid-gray only — zero saturation, no vibrant region exists anywhere.
    let pixels = Array(repeating: RGBColor(red: 128, green: 128, blue: 128), count: 100)

    let palette = ScoredSwatchesTechnique.extract(from: pixels)

    for color in palette {
        #expect(ColorConverter.hsl(from: color.rgb).saturation <= 0.4)
    }
}
