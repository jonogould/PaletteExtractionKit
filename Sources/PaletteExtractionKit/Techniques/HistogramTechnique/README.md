# HistogramTechnique

The simplest, crudest technique in the package: quantize, tally, take the top buckets by frequency. No perceptual distance, no iteration — deliberate contrast with the techniques elsewhere in this package that genuinely cluster in L\*a\*b\* space (`KMeansTechnique`, `FloodFillTechnique`), which group colors by how similar humans perceive them to be. Here, two visually near-identical colors that happen to fall in different quantization buckets are treated as completely unrelated.

## How it works

1. Filter by `minimumAlpha`, downsample to `quality.maxSamples`.
2. For each sampled pixel, right-shift each of R/G/B down to `bitsPerChannel` bits, producing a quantized bucket key.
3. In a single pass, tally each bucket's pixel count and running R/G/B sum in a `[Int: (count, sumR, sumG, sumB)]` dictionary.
4. Take the top `colorCount` buckets by count.
5. Each returned color is the true average of the actual pixels that landed in that bucket — not the bucket's quantized "center" color. Averaging the real pixels avoids a posterized look; using the center color would look visibly wrong even though the bucketing-by-frequency logic is otherwise unaffected.

Percentage is computed relative to the total sampled pixel count, not the sum of the returned top-K buckets. If buckets outside the top-K exist, the returned colors' percentages won't necessarily sum to 100% — that's intentional, since it reflects each color's true share of the image rather than an inflated share among only the colors shown.

## Options (`HistogramOptions`)

| Field | Default | Meaning |
|---|---|---|
| `colorCount` | 4 | Number of top buckets to return. |
| `quality` | `.balanced` | Governs sampling. |
| `minimumAlpha` | 128 | Alpha cutoff. |
| `bitsPerChannel` | 4 | Bits kept per RGB channel (clamped 1–8), controlling bucket granularity. Higher means finer buckets — closer to exact colors but less tolerant of near-duplicate shades landing in the same bucket. |

## Complexity

O(samples) — a single pass over the sampled pixels to build the histogram, plus a sort of the resulting buckets (far fewer than the sample count). No box-splitting search, no tree construction, no iteration to convergence. The fastest technique in this package by a wide margin.

## When to use it

Good as a quick baseline, or whenever raw speed matters more than palette quality. Works reasonably well on images with a few genuinely dominant flat colors. On photos with smooth gradients or subtle shading, results look noticeably more "blocky" than every other technique here, since there's zero perceptual grouping logic — quantization boundaries can arbitrarily split what should be one color into several buckets, or lump together colors that only coincidentally quantize to the same bucket.

## Example

```swift
let palette = try await image.labPalette(quality: .fast, using: HistogramTechnique(options: .init(colorCount: 4, bitsPerChannel: 4)))
```
