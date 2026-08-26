# Changelog

## 0.2.0

No changes to the library's public API — additive/tooling only.

- Added `.spi.yml` to host DocC documentation on the Swift Package Index (builds against iOS).
- Added `PaletteExtractionDemo`, a SwiftUI iOS demo app, under `demo/` — exercises all 10 techniques via a multi-select picker (chip grid, sorted by popularity/ease, wraps via a custom `FlowLayout`), a "colors to extract" stepper, and horizontally-scrollable swatch rows. Depends on this package via a local path reference, so it always builds against current source.

## 0.1.0

- Initial release.
- Ten `PaletteExtractionTechnique` conformers: `KMeansTechnique`, `FloodFillTechnique`, `MedianCutTechnique`, `ModifiedMedianCutTechnique` (MMCQ/color-thief), `WuQuantizationTechnique`, `OctreeQuantizationTechnique`, `HistogramTechnique`, `AgglomerativeTechnique`, `AverageColorTechnique`, `ScoredSwatchesTechnique` (Android Palette-style).
- Open protocol architecture — new techniques conform and drop in with zero changes to the package. No enum to extend, no switch statement to edit, no central registry.
- `PaletteExtractor.extract(from:using:)` / `.extractMany(from:using:)` — single or multiple techniques, run concurrently via `TaskGroup`, order-preserving.
- `UIImage`/`NSImage` extensions: `labPalette(quality:using:)` and `labPalettes(quality:using:)`.
- L\*a\*b\* color math (`LabColor`, `ColorConverter`), Delta E 76 and Delta E 2000 distance support, HSL support (`HSLColor`, `ColorConverter.hsl(from:)`) for saturation/lightness-based techniques.
- `PaletteQuality` presets (`.fast`, `.balanced`, `.high`) trading accuracy for speed.
- Swift 6, strict concurrency, iOS 18 / macOS 15.
