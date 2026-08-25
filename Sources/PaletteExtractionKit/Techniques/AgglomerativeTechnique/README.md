# AgglomerativeTechnique

Bottom-up hierarchical merge clustering in L\*a\*b\* space. It's the structural opposite of the other two clustering families in this package: K-means starts with `colorCount` clusters and iterates them toward convergence, and the median-cut family starts with a single box and repeatedly splits it downward. Agglomerative clustering starts with many small clusters and repeatedly merges the closest pair upward until only `colorCount` remain.

## How it works

1. Filter out pixels below `minimumAlpha`, then downsample to at most `quality.maxSamples` pixels via even stride.
2. Pre-bucket the sampled pixels into a bounded candidate set (at most `maxClusters`, default 256) via a coarse RGB histogram: pick `bitsPerChannel` dynamically, starting at 5 and decreasing until `levels³` stays within roughly `maxClusters × 4` buckets, then average each occupied bucket's pixels into one candidate cluster (with population and running RGB sums). This keeps the number of things being merged bounded regardless of how many pixels were sampled — naive pairwise agglomeration over thousands of raw pixels would be O(n³), far too slow. This pre-bucketing is intentionally *not* shared with `HistogramTechnique`, even though the two are conceptually similar: the code comment in the source notes it's simple enough (~15 lines) that duplicating it was cheaper than coupling two otherwise-independent techniques together.
3. Convert each candidate cluster's average RGB to L\*a\*b\*.
4. Repeat until only `colorCount` clusters remain: scan every current pair of clusters, find the closest pair by Delta-E distance (via the shared internal `ColorClustering.distance` on their Lab means — the same helper `KMeansTechnique` and `FloodFillTechnique` use), and merge them into one cluster whose Lab value is the population-weighted average of the two.
5. Sort by population (largest cluster first) and return.

## Options (`AgglomerativeOptions`)

| Field | Default | Meaning |
|---|---|---|
| `colorCount` | 4 | Target number of clusters/colors after merging finishes. |
| `quality` | `.balanced` | Governs sampling before pre-bucketing. |
| `minimumAlpha` | 128 | Pixels below this alpha are excluded entirely. |
| `maxClusters` | 256 | Cap on the pre-bucket candidate set — the knob unique to this technique, and the main lever on both quality and runtime. |
| `deltaEMethod` | `.deltaE2000` | Distance metric used to find the closest pair each merge round. |

## Complexity

Pre-bucketing is O(samples). The merge loop is the expensive part: each round rescans every current pair to find the closest one, and there's no cached distance matrix or nearest-neighbor-chain optimization — it's a naive "rescan everything every round" approach, chosen for implementation simplicity over raw speed. Worst case that's on the order of `maxClusters³` distance calculations (~256³ ≈ 16 million with the default), which the source's own comments describe as acceptable in a background `Task.detached` at this package's scale — a few thousand sampled pixels pre-bucketed down to at most 256 representative colors. A proper nearest-neighbor-chain or cached distance matrix would scale better, but wasn't needed at this scale; if `maxClusters` were ever raised significantly, this is the first thing that would need revisiting.

## When to use it

Produces results broadly comparable to the median-cut family — bottom-up merging naturally respects actual color density, similar in spirit to how MMCQ's weighted-median split follows where the pixels actually are, just built from the opposite direction. It's a good fit when you want a technique that starts from many small buckets and coalesces them rather than one that starts from a few boxes and divides them — conceptually a better match for images with many small, distinct-but-related color patches that should get merged together rather than carved out of a handful of big volumes.

## Example

```swift
let palette = try await image.labPalette(quality: .balanced, using: AgglomerativeTechnique(options: .init(colorCount: 5)))
```
