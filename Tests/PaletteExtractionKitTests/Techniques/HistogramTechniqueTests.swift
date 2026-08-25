import Testing
@testable import PaletteExtractionKit

@Test func histogramFindsTwoDominantColors() {
    let pixels = Array(repeating: RGBColor(red: 255, green: 0, blue: 0), count: 100)
        + Array(repeating: RGBColor(red: 0, green: 0, blue: 255), count: 50)

    let palette = HistogramTechnique.extract(from: pixels, options: HistogramOptions(colorCount: 2))

    #expect(palette.count == 2)
    #expect(palette[0].population == 100)
    #expect(palette[0].rgb.red > 200)
    #expect(palette[1].rgb.blue > 200)
}

@Test func histogramRespectsRequestedColorCount() {
    let pixels = Array(repeating: RGBColor(red: 255, green: 0, blue: 0), count: 60)
        + Array(repeating: RGBColor(red: 0, green: 255, blue: 0), count: 60)
        + Array(repeating: RGBColor(red: 0, green: 0, blue: 255), count: 60)

    let palette = HistogramTechnique.extract(from: pixels, options: HistogramOptions(colorCount: 3))

    #expect(palette.count == 3)
}
