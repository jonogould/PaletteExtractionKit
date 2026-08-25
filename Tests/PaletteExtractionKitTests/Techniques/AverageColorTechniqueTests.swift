import Testing
@testable import PaletteExtractionKit

@Test func averageColorReturnsExactlyOneSwatch() {
    let pixels = Array(repeating: RGBColor(red: 255, green: 0, blue: 0), count: 100)
        + Array(repeating: RGBColor(red: 0, green: 0, blue: 255), count: 100)

    let palette = AverageColorTechnique.extract(from: pixels)

    #expect(palette.count == 1)
    #expect(palette[0].population == 200)
    #expect(palette[0].percentage == 1)
}

@Test func averageColorOfSolidBlockMatchesThatColor() {
    // Same ±1 tolerance as the base RGB↔Lab roundtrip test — averaging identical
    // values still goes through the same pivot-function rounding on the way back.
    let pixels = Array(repeating: RGBColor(red: 10, green: 20, blue: 30), count: 50)

    let palette = AverageColorTechnique.extract(from: pixels)

    #expect(palette.count == 1)
    #expect(abs(Int(palette[0].rgb.red) - 10) <= 1)
    #expect(abs(Int(palette[0].rgb.green) - 20) <= 1)
    #expect(abs(Int(palette[0].rgb.blue) - 30) <= 1)
}
