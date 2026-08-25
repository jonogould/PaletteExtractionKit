# OctreeQuantizationTechnique

Gervautz-Purgathofer octree color quantization — the classic algorithm behind old GIF encoders. Instead of clustering colors by iterative refinement or splitting a histogram box, it builds a tree where every unique 24-bit RGB value has its own path, then prunes that tree down to `colorCount` leaves.

## How it works

1. Filter by `minimumAlpha`, downsample to `quality.maxSamples`.
2. Insert every sampled pixel into an 8-level-deep octree, one insertion per pixel. At level *i*, the child index (0–7) is picked from bit `(7 - i)` of each of R, G, B, combined into a 3-bit index — so a pixel's path through the tree is literally its bits, read from the most-significant bit down. By depth 8, every unique 24-bit RGB value has traced out its own leaf.
3. Leaf nodes, created the first time a pixel reaches depth 8, accumulate sum-R/G/B and a pixel count rather than storing individual pixels.
4. Once every pixel is inserted, if the leaf count exceeds `colorCount`, repeatedly reduce: find the *deepest* node whose existing children are all leaves, and among ties at that depth pick whichever has the fewest total pixels — sacrificing the least-significant, least-visually-important cluster first. Merge that node's leaf children up into itself (summing their counts and RGB sums, removing them, marking the parent as the new leaf). Repeat until the leaf count is at or below `colorCount`.
5. Collect the surviving leaves, average each one's accumulated sums into a final RGB color, and sort by population.

The tree itself is a private `final class Node` — a reference type, needed so children can be mutated in place during both insertion and reduction. That's safe under Swift 6 strict concurrency specifically because the whole tree is built and torn down entirely inside one synchronous function call: it never crosses an `await` while alive, so it never needs to be `Sendable`.

## Options (`OctreeQuantizationOptions`)

| Field | Default | Meaning |
|---|---|---|
| `colorCount` | 4 | Target leaf count after reduction. |
| `quality` | `.balanced` | Governs sampling. |
| `minimumAlpha` | 128 | Alpha cutoff. |

Same minimal shape as the median-cut options — no Delta-E method, since this works entirely in raw RGB bit-space, not Lab.

## Complexity

Insertion is O(pixels × 8) — each pixel walks exactly 8 levels regardless of image content. Reduction cost scales with how many distinct colors exceed `colorCount`: each reduction round does a full tree scan to find the deepest all-leaf-children node, so images with a lot of distinct colors and a small requested `colorCount` run more rounds. Each round is fast at this package's sample scale (a few thousand pixels), but it's the one place this technique isn't strictly linear in the sample count.

## When to use it

Distinct colors diverge into completely separate branches from the very first level, so it's remarkably robust at keeping visually distinct colors separate regardless of population imbalance — a small, saturated logo color won't get absorbed into a much larger background cluster the way it might with a population-weighted split. Best for images with a small number of genuinely distinct flat colors: logos, icons, simple vector-style graphics. Less suited to photos or gradients, where the 24-bit address space is densely populated and reduction has to do real work merging nearby-but-not-identical colors.

## Example

```swift
let palette = try await image.labPalette(quality: .balanced, using: OctreeQuantizationTechnique(options: .init(colorCount: 5)))
```
