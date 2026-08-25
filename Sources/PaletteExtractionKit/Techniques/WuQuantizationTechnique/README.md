# WuQuantizationTechnique

Xiaolin Wu's variance-minimizing color quantizer — the algorithm ImageMagick and .NET's `System.Drawing` both ship as their default palette reducer. Unlike the median-cut family, which splits boxes by population×volume or a weighted-median cut point, Wu's approach splits whichever box currently contributes the most color variance, and picks the cut that leaves the two children with the least *combined* variance. It's classic literature (Wu's 1991 "Graphics Gems II" chapter), and this implementation follows the original moment-based formulation directly rather than approximating it.

## How it works

Built on a private `WuQuantizer` engine — the 3D-moment box splitting here isn't shared with anything else in the package, so it stays local to this file rather than living alongside `MedianCutQuantizer`.

1. Filter by `minimumAlpha`, downsample to `quality.maxSamples`.
2. Quantize each pixel's R/G/B to 5 bits (32 levels) and bucket it into a `33×33×33` histogram — 32 levels **plus one**, because every quantized coordinate is stored offset by `+1`. Index `0` on every axis is left as a permanent zero boundary. That's what lets the box-query math below treat every box's lower edge uniformly, including boxes that touch the histogram's true edge, without any special-casing.
3. Accumulate five running sums per bucket while scanning pixels: `weight` (pixel count), `momentR`/`momentG`/`momentB` (summed channel values), and `momentSq` (summed `r²+g²+b²`).
4. Convert all five tables into full 3D cumulative (summed-volume) tables in place, one axis at a time — the exact 3D generalization of a 2D integral image. This is a fixed-cost pass over `33³` buckets regardless of how many pixels were sampled.
5. Querying any axis-aligned sub-box's moments after that is an O(1) lookup: the standard 8-corner inclusion-exclusion sum on a cumulative table.
6. Start with one box spanning the full cube. Repeatedly pick the box with the **largest variance** — `momentSq − (momentR²+momentG²+momentB²)/weight` — and split it, until `colorCount` boxes exist or no box can be split further. This is the key departure from MMCQ's population×volume heuristic: Wu splits based on how much color spread a box actually contains, not how big or populous it is.
7. To split a box: try every interior cut point on all three axes (every unit boundary strictly inside the box's range on R, then G, then B) and score each candidate by `(momentR₁²+momentG₁²+momentB₁²)/weight₁ + (same for child 2)`. Keep whichever cut maximizes that sum. This is mathematically equivalent to minimizing the two children's *total* post-split variance — the parent's `momentSq` term is a constant no matter where you cut, so maximizing the squared-moment term is the same thing as minimizing variance, just cheaper to compute per candidate.
8. Each final box's output color is the true weighted average (`momentR/weight`, etc.) of the pixels landing inside it, not the box's geometric center.

## Options (`WuQuantizationOptions`)

| Field | Default | Meaning |
|---|---|---|
| `colorCount` | 4 | Target number of boxes/colors. |
| `quality` | `.balanced` | Governs sampling. |
| `minimumAlpha` | 128 | Alpha cutoff. |

Same minimal shape as `ModifiedMedianCutOptions` — no Delta-E method. Everything here operates in quantized RGB moment space; Lab conversion only happens once, on the final averaged box colors.

## Complexity

O(pixels) to build the histogram, then a fixed O(33³) pass to build the cumulative moment tables — that cost doesn't scale with sample count, so it's effectively free at this package's `quality` sample caps. Splitting is bounded by `colorCount − 1` splits, each scanning every candidate box (largest-variance search) and then every interior cut on 3 axes of the chosen box (up to ~93 candidates for a full 32-wide box), with each candidate a handful of O(1) table lookups. In practice this is the fastest of the box-splitting techniques once the histogram is built, since there's no re-scanning of pixel data after that point — everything downstream is table lookups.

## When to use it

Wu's quantizer is widely regarded as the best general-purpose classic quantizer — it's literally why ImageMagick and .NET picked it as their default rather than median cut or octree. Use it when you want the highest-quality box-splitting palette without paying k-means's iteration cost.

The tradeoff is implementation risk rather than runtime cost: the 3D moment math and the `+1`-offset histogram indexing are the easiest thing in this package to get subtly wrong (an off-by-one in the cumulative-table bounds silently produces wrong variances rather than crashing). Treat this technique with extra scrutiny in review and tests relative to the more mechanically simple median-cut family.

## Example

```swift
let palette = try await image.labPalette(quality: .balanced, using: WuQuantizationTechnique(options: .init(colorCount: 6)))
```
