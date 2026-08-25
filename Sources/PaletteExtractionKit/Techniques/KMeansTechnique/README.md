# KMeansTechnique

K-means clustering in L\*a\*b\* color space, using perceptual Delta-E distance instead of raw RGB distance. This is the package's default, general-purpose technique — a good overall representative palette for most photos.

## How it works

1. Filter out pixels below `minimumAlpha`, then downsample to at most `maxSamples` pixels via even stride (not random — deterministic, and preserves the image's spatial distribution reasonably well).
2. Convert each sampled pixel to L\*a\*b\*.
3. Pick initial centroids via a farthest-point heuristic: start with the first pixel, then repeatedly add whichever remaining pixel is farthest (by Delta-E) from all centroids picked so far. This spreads the initial guesses out, which converges faster and more reliably than random initialization (a close cousin of the well-known "k-means++" seeding strategy).
4. Iterate up to `maxIterations` times: assign every sampled pixel to its nearest centroid, recompute each centroid as the mean of its assigned pixels, and stop early once the average centroid movement drops below `convergenceThreshold`.
5. Merge any two final clusters whose Delta-E distance is within `mergeThreshold` — this cleans up near-duplicate clusters that k-means sometimes produces when `colorCount` is set higher than the image's actual number of distinct color regions.
6. Sort by population (largest cluster first) and return.

## Options (`PaletteOptions`)

| Field | Default | Meaning |
|---|---|---|
| `colorCount` | 8 | Number of clusters/colors to extract. |
| `quality` | `.balanced` | Governs `maxSamples` unless overridden. |
| `maxSamples` | from `quality` | Pixels actually clustered, after downsampling. |
| `maxIterations` | 30 | Hard cap on k-means iterations. |
| `convergenceThreshold` | 0.25 | Average centroid Delta-E movement below which iteration stops early. |
| `minimumAlpha` | 128 | Pixels below this alpha are excluded entirely. |
| `mergeThreshold` | 4.0 | Delta-E distance below which two final clusters get merged into one. |
| `deltaEMethod` | `.deltaE2000` | `.deltaE76` (simple Euclidean in Lab) or `.deltaE2000` (perceptually corrected, slower to reason about but more accurate for near-color discrimination). |

## Complexity

O(samples × colorCount × iterations). Dominates the package's other clustering-style techniques in raw cost, but produces the most perceptually even palette since it directly optimizes for minimizing within-cluster Delta-E.

## When to use it

Default choice for "just give me a good palette." Slower than the box-splitting techniques (median cut family, Wu, octree) but tends to produce the most visually balanced result across a wide variety of photos, since it's directly optimizing perceptual distance rather than splitting a bounding volume.

## Example

```swift
let palette = try await image.labPalette(quality: .balanced, using: KMeansTechnique(options: .init(colorCount: 6)))
```
