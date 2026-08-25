# FloodFillTechnique

Finds connected regions of similar color in L\*a\*b\* space via breadth-first flood fill, rather than clustering colors globally. Useful when you care about *where* a color lives, not just how much of it exists — big flat visual blocks, UI screenshots, posters, illustrations, product shots on solid backgrounds.

## How it works

1. Filter by `minimumAlpha`, downsample to `quality.maxSamples`.
2. Unlike every other technique in this package, flood fill needs the image's actual 2D layout (`PixelImage.width`/`height`), not just a flat pixel list — it walks a grid, not a point cloud.
3. Scan pixels in order; for each unvisited pixel, treat it as a seed and BFS outward to its 4-connected neighbors (up/down/left/right), adding a neighbor to the region only if its Delta-E distance to the *seed* color is within `similarityThreshold`.
4. Discard regions smaller than `minimumRegionPercentage` of the total pixel count — this is what keeps single stray pixels or thin anti-aliased edges from becoming their own "color."
5. Each surviving region's color is the mean of its member pixels.
6. Merge regions within `mergeThreshold` of each other (same merge step as `KMeansTechnique`, same underlying `ColorClustering.mergeSimilar`), sort by population, return.

## Options (`FloodFillOptions`)

| Field | Default | Meaning |
|---|---|---|
| `colorCount` | 4 | Max regions returned. |
| `quality` | `.balanced` | Governs sampling/downsampling. |
| `minimumAlpha` | 128 | Alpha cutoff. |
| `similarityThreshold` | 12 | Max Delta-E from a region's seed pixel for a neighbor to join it. Lower = more, smaller, purer regions; higher = fewer, larger, more tolerant regions. |
| `mergeThreshold` | 5 | Delta-E below which two separate regions get merged after the fact. |
| `minimumRegionPercentage` | 0.003 (0.3%) | Regions smaller than this fraction of the image are discarded. |
| `deltaEMethod` | `.deltaE2000` | Same choice as every other technique. |

## Complexity

O(sampled pixels) — one BFS pass over the grid, each pixel visited once. Cheaper than K-means in practice since there's no iterative refinement, but it needs the full 2D `PixelImage`, so it can't operate on a bare `[RGBColor]` array the way most other techniques' low-level entry points can.

## When to use it

Best for images with genuinely large, spatially contiguous color blocks — logos, flat illustrations, UI mockups, product photography on clean backgrounds. Weakest on photos with lots of gradients or texture, where similarity-threshold BFS tends to fragment into many small regions that then get filtered out by `minimumRegionPercentage`, potentially returning fewer colors than requested.

## Example

```swift
let palette = try await image.labPalette(quality: .balanced, using: FloodFillTechnique(options: .init(colorCount: 4, similarityThreshold: 15)))
```
