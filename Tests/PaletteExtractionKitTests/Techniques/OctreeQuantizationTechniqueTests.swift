import Testing
@testable import PaletteExtractionKit

@Test func octreeFindsTwoDominantColors() {
    let pixels = Array(repeating: RGBColor(red: 255, green: 0, blue: 0), count: 100)
        + Array(repeating: RGBColor(red: 0, green: 0, blue: 255), count: 50)

    let palette = OctreeQuantizationTechnique.extract(from: pixels, options: OctreeQuantizationOptions(colorCount: 2))

    #expect(palette.count == 2)
    #expect(palette[0].population == 100)
    #expect(palette[0].rgb.red > 200)
    #expect(palette[1].rgb.blue > 200)
}

@Test func octreeReducesToRequestedColorCount() {
    // Four fully distinct colors, but only 2 requested — must reduce leaves down to 2.
    let pixels = Array(repeating: RGBColor(red: 255, green: 0, blue: 0), count: 40)
        + Array(repeating: RGBColor(red: 200, green: 10, blue: 5), count: 40)
        + Array(repeating: RGBColor(red: 0, green: 0, blue: 255), count: 40)
        + Array(repeating: RGBColor(red: 5, green: 0, blue: 200), count: 40)

    let palette = OctreeQuantizationTechnique.extract(from: pixels, options: OctreeQuantizationOptions(colorCount: 2))

    #expect(palette.count == 2)
    #expect(palette.reduce(0) { $0 + $1.population } == 160)
}
