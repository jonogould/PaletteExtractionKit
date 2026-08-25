# AverageColorTechnique

The mean color of the entire image, in L\*a\*b\* space, returned as a single swatch. This is the simplest technique in the package — no boxes, no clusters, no iteration — and it isn't really "palette extraction" in the multi-color sense at all.

## How it works

1. Filter out pixels below `minimumAlpha`, then downsample to `quality.maxSamples` via even stride, same as every other technique.
2. Convert each sampled pixel to L\*a\*b\* and sum the vectors.
3. Divide the sum by the sample count to get the average Lab vector, then convert that single averaged value back to RGB.
4. Return exactly one `PaletteColor`, with `population` set to the sampled pixel count and `percentage` fixed at `1.0` (it's the entire sample, since there's nothing else to compare it against).

Averaging happens in Lab, not raw RGB, consistent with the rest of the package treating Lab as ground truth for color math — averaging very different hues directly in RGB tends to produce muddier, less perceptually meaningful midpoints.

## Options (`AverageColorOptions`)

| Field | Default | Meaning |
|---|---|---|
| `quality` | `.balanced` | Governs `maxSamples` for downsampling. |
| `minimumAlpha` | 128 | Pixels below this alpha are excluded entirely. |

No `colorCount` — it would be meaningless for a technique that only ever produces one output. Consistent with the package's design philosophy (see also `ScoredSwatchesTechnique`): when a field doesn't apply to a technique, it's omitted entirely rather than included and silently ignored.

## Complexity

O(samples) — one pass to sum, one conversion back to RGB. Cheapest technique in the package by a wide margin.

## When to use it

When you want a single representative accent color rather than a palette — a background gradient tint or UI chrome color derived from whatever photo the user picked, an app icon's "vibe color," album-art tinting. Not useful when you need multiple distinct swatches. Also a good starting point for understanding the `PaletteExtractionTechnique` protocol, since it has none of the box-splitting or clustering machinery found elsewhere in the package.

## Example

```swift
let palette = try await image.labPalette(quality: .balanced, using: AverageColorTechnique())
let vibeColor = palette.first
```
