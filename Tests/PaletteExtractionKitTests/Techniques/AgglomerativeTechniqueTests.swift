import Testing
@testable import PaletteExtractionKit

@Test func agglomerativeMergesDownToTwoDominantColors() {
    let pixels = Array(repeating: RGBColor(red: 255, green: 0, blue: 0), count: 100)
        + Array(repeating: RGBColor(red: 0, green: 0, blue: 255), count: 50)

    let palette = AgglomerativeTechnique.extract(from: pixels, options: AgglomerativeOptions(colorCount: 2))

    #expect(palette.count == 2)
    #expect(palette[0].population == 100)
    #expect(palette[0].rgb.red > 200)
    #expect(palette[1].rgb.blue > 200)
}

@Test func agglomerativeRespectsRequestedColorCount() {
    let pixels = Array(repeating: RGBColor(red: 255, green: 0, blue: 0), count: 60)
        + Array(repeating: RGBColor(red: 0, green: 255, blue: 0), count: 60)
        + Array(repeating: RGBColor(red: 0, green: 0, blue: 255), count: 60)

    let palette = AgglomerativeTechnique.extract(from: pixels, options: AgglomerativeOptions(colorCount: 3))

    #expect(palette.count == 3)
}
