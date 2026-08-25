# MedianCutTechnique

Classic median cut quantization, in plain RGB — not L\*a\*b\*. This is deliberate: it's the historically "correct" naive version of the algorithm (the one used by early GIF encoders), kept as a baseline contrast to the perceptual, Lab-based techniques elsewhere in this package.

## How it works

1. Filter by `minimumAlpha`, downsample to `quality.maxSamples`.
2. Start with a single "box" containing every sampled pixel.
3. Repeat until `colorCount` boxes exist (or no box can be split further):
   - Find the box with the largest range on any single RGB channel (`max − min` for R, G, or B).
   - Sort that box's pixels along whichever channel had the largest range.
   - Split at the **index** median — i.e., bisect by pixel *count*, not by where the colors actually cluster.
4. Each final box's color is the true average of its pixels; population is the box's pixel count.

## The one property that matters for testing/intuition

Because the split is an index-median (bisect by count), median cut does **not** necessarily land on the natural boundary between two differently-sized color clusters. Given, say, 100 red pixels and 50 blue pixels, the median split lands 75 pixels into what should be a clean 100/50 split — producing one mixed box and one pure box, not two pure ones. This is a real, well-known property of classic median cut, not a bug: it optimizes for even population distribution per box, not for hitting natural color boundaries. `ModifiedMedianCutTechnique` (MMCQ) exists specifically to fix this.

## Options (`MedianCutOptions`)

| Field | Default | Meaning |
|---|---|---|
| `colorCount` | 4 | Target number of boxes/colors. |
| `quality` | `.balanced` | Governs sampling. |
| `minimumAlpha` | 128 | Alpha cutoff. |

No `deltaEMethod` or `mergeThreshold` — this technique works entirely in raw RGB and never computes a Delta-E distance.

## Complexity

O(samples log samples) per split (dominated by sorting the box being split), times up to `colorCount − 1` splits. Cheap, single-pass-ish, no iteration to convergence.

## When to use it

Mostly useful as a baseline for comparison against `ModifiedMedianCutTechnique`, or when you specifically want the classic/historical algorithm's behavior rather than a refined one. For production use, prefer MMCQ, Wu, or K-means — all three handle imbalanced clusters better.

## Example

```swift
let palette = try await image.labPalette(quality: .balanced, using: MedianCutTechnique(options: .init(colorCount: 5)))
```
