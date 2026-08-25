# ModifiedMedianCutTechnique (MMCQ)

Modified Median Cut Quantization — the algorithm behind "color-thief" and its many ports across JS, Python, and elsewhere. It's the most commonly cited answer to "how do I get the dominant colors out of an image," and fixes the main weakness of plain `MedianCutTechnique`: it doesn't blindly bisect by pixel count, it bisects by where the color density actually is.

## How it works

Built on the internal `MedianCutQuantizer` engine (shared with `ScoredSwatchesTechnique` — both need "split pixels into N representative boxes by population," just for different downstream purposes).

1. Filter by `minimumAlpha`, downsample to `quality.maxSamples`.
2. Quantize each pixel's R/G/B to 5 bits (32 levels per channel) and build a flat `32×32×32` histogram — a plain array, not a dictionary, indexed directly by `r*1024 + g*32 + b` — tracking pixel count *and* running R/G/B sums per bucket (needed for a true average later, not just the bucket's center color).
3. Start with one box covering the histogram's occupied range, tightened to the actual data extent (not the theoretical full 0–31 cube — an easy mistake that would make every early split pick an arbitrary axis instead of the one with real variance).
4. Repeatedly split the box with the largest `population × volume` score. To split: pick the box's longest axis, then walk it accumulating population until crossing **half the box's total population** — a *weighted* median, not an index median. This is the core fix over plain median cut: the cut lands where the color density actually splits, regardless of how unevenly sized the underlying clusters are.
5. Each output box's color is the true weighted average of the original pixels landing in its final range.

## Options (`ModifiedMedianCutOptions`)

| Field | Default | Meaning |
|---|---|---|
| `colorCount` | 4 | Target number of boxes/colors. |
| `quality` | `.balanced` | Governs sampling. |
| `minimumAlpha` | 128 | Alpha cutoff. |

Same minimal shape as `MedianCutOptions` — no Delta-E method, since the whole algorithm operates in quantized RGB.

## Complexity

Histogram build is O(samples). Each split evaluates a bounded number of candidate boxes and does an O(volume) scan to tighten/re-measure sub-boxes — cheap at this package's scale (a `32³` histogram is 32,768 buckets, trivial to scan a handful of times per split).

## When to use it

The general-purpose recommendation alongside K-means. If you want output that will look familiar to anyone who's used a "dominant colors" tool before (Chrome extensions, npm packages, etc.), this is the one — it's the same family of algorithm they're almost certainly using.

## Example

```swift
let palette = try await image.labPalette(quality: .balanced, using: ModifiedMedianCutTechnique(options: .init(colorCount: 5)))
```
