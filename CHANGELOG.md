# Changelog

## 0.1.0

- Initial release.
- Ten `PaletteExtractionTechnique` conformers: `KMeansTechnique`, `FloodFillTechnique`, `MedianCutTechnique`, `ModifiedMedianCutTechnique` (MMCQ/color-thief), `WuQuantizationTechnique`, `OctreeQuantizationTechnique`, `HistogramTechnique`, `AgglomerativeTechnique`, `AverageColorTechnique`, `ScoredSwatchesTechnique` (Android Palette-style).
- Open protocol architecture — new techniques conform and drop in with zero changes to the package. No enum to extend, no switch statement to edit, no central registry.
- `PaletteExtractor.extract(from:using:)` / `.extractMany(from:using:)` — single or multiple techniques, run concurrently via `TaskGroup`, order-preserving.
- `UIImage`/`NSImage` extensions: `labPalette(quality:using:)` and `labPalettes(quality:using:)`.
- L\*a\*b\* color math (`LabColor`, `ColorConverter`), Delta E 76 and Delta E 2000 distance support, HSL support (`HSLColor`, `ColorConverter.hsl(from:)`) for saturation/lightness-based techniques.
- `PaletteQuality` presets (`.fast`, `.balanced`, `.high`) trading accuracy for speed.
- Swift 6, strict concurrency, iOS 18 / macOS 15.
