<div align="center">

# 🎨 PaletteExtractionKit

**Swift palette extraction, done ten different ways.**

Perceptual L\*a\*b\* color science, ten extraction algorithms, one protocol — pick the technique that fits, or write your own with zero changes to this package.

[![Tests](https://github.com/jonogould/PaletteExtractionKit/actions/workflows/tests.yml/badge.svg)](https://github.com/jonogould/PaletteExtractionKit/actions/workflows/tests.yml)
[![Swift 6.0](https://img.shields.io/badge/Swift-6.0-F05138?logo=swift&logoColor=white)](https://swift.org)
[![Platforms](https://img.shields.io/badge/platforms-iOS%2018%20%7C%20macOS%2015-blue)](Package.swift)
[![SPM](https://img.shields.io/badge/SPM-compatible-brightgreen)](https://swift.org/package-manager/)
[![License: MIT](https://img.shields.io/badge/license-MIT-lightgrey)](LICENSE)

[Installation](#installation) · [Usage](#usage) · [Techniques](#techniques) · [Adding your own](#adding-a-new-technique) · [License](#license)

</div>

---

## What is this

PaletteExtractionKit pulls a color palette out of an image. That's it — but *how* it does that is the interesting part. Instead of hardcoding one algorithm, every technique conforms to a single protocol, `PaletteExtractionTechnique`, and the package ships ten of them: three flavors of clustering, four flavors of box-splitting quantization, one tree-based quantizer, one that isn't perceptual at all on purpose, and one that doesn't return a "palette" in the usual sense — it returns *roles* (Vibrant, Muted, and friends), Android-`androidx.palette`-style.

## Why

Most "get colors from an image" libraries pick one algorithm and stop. That's fine until it isn't — median cut is fast but bisects by pixel count, not by where the colors actually are; K-means is accurate but slow; Android's semantic swatches solve a completely different problem than "what are the top 4 colors." PaletteExtractionKit doesn't make you choose once — it makes choosing between them (and adding new ones) a non-event:

```swift
public protocol PaletteExtractionTechnique: Sendable {
    var name: String { get }
    var description: String { get }
    func extract(from image: PixelImage) async -> [PaletteColor]
}
```

No enum to extend, no switch statement to edit, no central registry. A technique is just a value you pass in.

## Installation

Swift Package Manager, via Xcode (File → Add Package Dependencies) or `Package.swift`:

```swift
.package(url: "https://github.com/jonogould/PaletteExtractionKit.git", from: "0.2.0")
```

## Usage

```swift
import UIKit
import PaletteExtractionKit

let results = try await image.labPalettes(
    quality: .balanced,
    using: [KMeansTechnique(), ModifiedMedianCutTechnique(), ScoredSwatchesTechnique()]
)

for result in results {
    print(result.name, result.colors.map(\.hex))
}
```

Or run just one:

```swift
let palette = try await image.labPalette(quality: .balanced, using: FloodFillTechnique())
```

## Techniques

Every technique below has a full writeup — algorithm, options reference, complexity, when to use it — as a `README.md` right next to its source, under `Sources/PaletteExtractionKit/Techniques/<Name>/`.

| Technique | What it does | Effectiveness | Popularity | Speed |
|---|---|---|---|---|
| [`KMeansTechnique`](Sources/PaletteExtractionKit/Techniques/KMeansTechnique/README.md) | Clusters pixels in L\*a\*b\* space, iterating to convergence | High | High | Medium |
| [`ModifiedMedianCutTechnique`](Sources/PaletteExtractionKit/Techniques/ModifiedMedianCutTechnique/README.md) (MMCQ) | The "color-thief" algorithm — population-weighted median cut | High | **Highest** | Fast |
| [`WuQuantizationTechnique`](Sources/PaletteExtractionKit/Techniques/WuQuantizationTechnique/README.md) | Variance-minimizing quantizer, ImageMagick's/.NET's default | **Highest** | Medium | Fast |
| [`ScoredSwatchesTechnique`](Sources/PaletteExtractionKit/Techniques/ScoredSwatchesTechnique/README.md) | Android Palette–style semantic swatches, not top-N | High* | **Highest** | Medium |
| [`OctreeQuantizationTechnique`](Sources/PaletteExtractionKit/Techniques/OctreeQuantizationTechnique/README.md) | Tree-based quantizer, classic GIF-encoder lineage | Medium-High | Medium | Fast |
| [`FloodFillTechnique`](Sources/PaletteExtractionKit/Techniques/FloodFillTechnique/README.md) | Connected-region detection in L\*a\*b\* space | Medium-High† | Medium | Fast |
| [`AgglomerativeTechnique`](Sources/PaletteExtractionKit/Techniques/AgglomerativeTechnique/README.md) | Bottom-up nearest-pair merging in L\*a\*b\* space | Medium | Low-Medium | Medium |
| [`MedianCutTechnique`](Sources/PaletteExtractionKit/Techniques/MedianCutTechnique/README.md) | Classic median cut, plain RGB, the historical baseline | Medium | Medium-High | Fast |
| [`HistogramTechnique`](Sources/PaletteExtractionKit/Techniques/HistogramTechnique/README.md) | Quantize, tally, take the top buckets — zero perceptual logic | Low-Medium | Low | **Fastest** |
| [`AverageColorTechnique`](Sources/PaletteExtractionKit/Techniques/AverageColorTechnique/README.md) | Mean color of the whole image, one swatch | N/A‡ | Medium | **Fastest** |

\* Effective for its own job — semantic role-matching, not top-N accuracy.
† Best on large flat color blocks; weaker on gradients/texture.
‡ Not really "extraction" — a single accent color, not a palette.

## Demo app

A SwiftUI iOS app exercising all 10 techniques via a picker UI lives at [`demo/`](demo/README.md) — open `demo/PaletteExtractionDemo.xcodeproj`, pick a photo, and compare palettes side by side.

## Adding a new technique

This is the entire point of the architecture: a new technique needs zero changes anywhere in this package. Conform to `PaletteExtractionTechnique`, and pass an instance wherever you'd pass a built-in one.

```swift
import PaletteExtractionKit

struct MyTechnique: PaletteExtractionTechnique {
    var name: String { "My technique" }
    var description: String { "One sentence describing what makes it different" }

    func extract(from image: PixelImage) async -> [PaletteColor] {
        // image.pixels: [RGBColor], image.width/height if you need the 2D grid
        // ColorConverter.lab(from:) / .rgb(from:) to move between color spaces
        // ColorConverter.hsl(from:) if saturation/lightness bands matter more than perceptual distance
        // Build [PaletteColor(rgb:, lab:, population:, percentage:)], sorted however makes sense for your algorithm
    }
}
```

Then use it exactly like a built-in:

```swift
let palette = try await image.labPalette(using: MyTechnique())

// or alongside others:
let results = try await image.labPalettes(using: [KMeansTechnique(), MyTechnique()])
```

A few conventions the built-in techniques follow, worth matching if you want your technique to feel native:

- **Filter by alpha first.** `pixels.filter { $0.alpha >= options.minimumAlpha }` before doing anything else.
- **Downsample to `quality.maxSamples`** via even stride, not random sampling — deterministic, preserves spatial distribution reasonably well.
- **Own your own `Options` struct.** Don't reuse another technique's — each technique's tunable knobs are its own concern (see `PaletteOptions` vs. `FloodFillOptions` vs. `ScoredSwatchesOptions` for how differently-shaped these can be).
- **Omit fields that don't apply**, rather than including-and-ignoring them (`AverageColorTechnique` and `ScoredSwatchesTechnique` both skip `colorCount` entirely — it's meaningless for what they return).
- **Keep a sync, testable core.** Every built-in has a `public static func extract(from pixels:, options:) -> [PaletteColor]` doing the real work synchronously, with the instance `extract(from image:) async` and a `public static func extractAsync` just wrapping it in `Task.detached`. Makes unit testing trivial — no `async`/`await` needed for the actual algorithm test.
- **Write a `README.md` next to it.** See any existing technique's for the expected shape: how it works, options table, complexity, when to use it, example.

## License

MIT — see [LICENSE](LICENSE).
