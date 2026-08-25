import Testing
@testable import PaletteExtractionKit

@Test func medianCutSplitsBalancedRegionsCleanly() {
    // Classic median cut bisects by population count, not natural color boundaries —
    // use equal-sized blocks so the median split lands exactly on the true boundary.
    let pixels = Array(repeating: RGBColor(red: 255, green: 0, blue: 0), count: 80)
        + Array(repeating: RGBColor(red: 0, green: 0, blue: 255), count: 80)

    let palette = MedianCutTechnique.extract(from: pixels, options: MedianCutOptions(colorCount: 2))

    #expect(palette.count == 2)
    #expect(palette.allSatisfy { $0.population == 80 })
    #expect(palette.contains { $0.rgb.red > 200 && $0.rgb.blue < 50 })
    #expect(palette.contains { $0.rgb.blue > 200 && $0.rgb.red < 50 })
}

@Test func medianCutRespectsRequestedColorCount() {
    let pixels = Array(repeating: RGBColor(red: 255, green: 0, blue: 0), count: 60)
        + Array(repeating: RGBColor(red: 0, green: 255, blue: 0), count: 60)
        + Array(repeating: RGBColor(red: 0, green: 0, blue: 255), count: 60)

    let palette = MedianCutTechnique.extract(from: pixels, options: MedianCutOptions(colorCount: 3))

    #expect(palette.count == 3)
}
