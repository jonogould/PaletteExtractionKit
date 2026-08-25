# ScoredSwatchesTechnique

Android `androidx.palette`-style semantic swatches: Vibrant, LightVibrant, DarkVibrant, Muted, LightMuted, DarkMuted. Rather than a plain top-N "these are the dominant colors" palette, this technique answers a different question — "give me the accent color a UI would use," in up to six named roles. It's the most structurally different technique in the package: every other technique returns a ranked, padded-to-`colorCount` list; this one returns a sparse, positionally-fixed selection that can legitimately be empty.

## How it works

1. Filter by `minimumAlpha`, downsample to `quality.maxSamples`.
2. **Get raw candidates.** Calls the shared internal `MedianCutQuantizer.quantize(pixels:targetBoxCount:)` with `options.candidateCount` as the target box count — the exact same box-splitting engine `ModifiedMedianCutTechnique` (MMCQ) uses. This is a deliberate architecture choice: box-splitting is "split pixels into N representative boxes by population," a single well-tested internal (non-public) engine, and both techniques consume it for different downstream purposes rather than reimplementing it.
3. **Convert to HSL.** Each candidate's RGB is converted via `ColorConverter.hsl(from:)`. This technique is the reason the package has HSL at all — the six categories are defined by saturation/lightness bands, which are naturally HSL properties, not perceptual-distance ones. Every technique's output still carries a `.lab` value (it's part of the shared `PaletteColor` struct), but only `KMeansTechnique`, `FloodFillTechnique`, and `AgglomerativeTechnique` actually use Lab *distance* in their core algorithm; this one needs HSL specifically because "vibrant"/"muted" are saturation concepts and "light"/"dark"/"normal" are lightness concepts — Lab doesn't cleanly separate those two axes the way HSL does.
4. **Score against 6 fixed target bands.** The six categories are each a `(luma target/min/max, saturation target/min/max)` tuple, with constants approximated from Android's published `androidx.palette` source (approximated from memory/documentation, not verified byte-exact against current AOSP — expect plausible Vibrant/Muted behavior, not a certified match to real Android output):
   - **Luma bands:** dark (target 0.26, max 0.45), normal (min 0.30, target 0.50, max 0.70), light (min 0.55, target 0.74).
   - **Saturation bands:** muted (target 0.30, max 0.40), vibrant (target 1.00, min 0.35).
   - A candidate whose saturation or lightness falls outside a category's min/max band is a **hard exclusion** from that category — it doesn't get a low score, it doesn't qualify at all.
   - Candidates that do qualify are scored: `3×(1 − |saturation − targetSaturation|) + 6×(1 − |luma − targetLuma|) + 1×(population / maxPopulation among all candidates)`. Luma fit dominates, saturation fit matters half as much, and population is a light tiebreaker among otherwise-similar candidates.
5. **Keep the best qualifier per category.** For each of the 6 categories, the highest-scoring qualifying candidate wins that slot. A category with no qualifying candidate is simply omitted — never backfilled from a nearby category, never padded with a fallback color.
6. **Emit in fixed order.** Results are appended in the fixed category order `[Vibrant, LightVibrant, DarkVibrant, Muted, LightMuted, DarkMuted]`, skipping any category that had no qualifier. The array is never re-sorted by score or population afterward.

## Options (`ScoredSwatchesOptions`)

| Field | Default | Meaning |
|---|---|---|
| `quality` | `.balanced` | Governs sampling. |
| `minimumAlpha` | 128 | Alpha cutoff. |
| `candidateCount` | 24 (clamped minimum 6) | The real tunable — how many raw boxes the quantizer produces before scoring. A higher value gives the scorer more raw material to find a good match per category (better odds all 6 slots qualify), at the cost of a bigger quantizer pass. |

Like `AverageColorTechnique`, this deliberately has **no `colorCount`** — it's meaningless for a fixed 6-category scorer; you don't ask for "3 vibrant colors," you ask for *the* Vibrant swatch.

## Complexity

Dominated by the shared `MedianCutQuantizer` pass: O(samples) to build the histogram plus a bounded number of box splits governed by `candidateCount`. Scoring itself is O(candidateCount × 6) — negligible next to quantization.

## When to use it

Reach for this when you need semantically meaningful theme colors — an accent color for UI chrome, a "now playing" background tint, anything matching Material Design's classic "pull a vibrant or muted color out of album art" pattern — rather than a plain descriptive palette. This is a genuinely different job than every other technique in the package: the others answer "what colors are in this image," this one answers "which of six specific *roles* does this image's color content fill, if any."

**Critical caveat on identifying a swatch's category:** `PaletteColor`, the return type shared by every technique in this package, carries no label/category field — the protocol wasn't extended just for this technique. So the only way to know "is this entry Vibrant or Muted?" is:
- **By position, using the fixed relative order documented above** — e.g. if only Vibrant and Muted qualified, the result array has exactly 2 entries, Vibrant first, Muted second, with no padding for the 4 missing slots. Array index is *not* stable across images (index 1 might be LightVibrant on one image and Muted on another), only the *relative order* of whichever categories did qualify is stable.
- **More robustly, by re-measuring HSL.** Call `ColorConverter.hsl(from: color.rgb)` on a result and check which category's band it falls into. This is unambiguous and doesn't depend on remembering the ordering convention.

Don't assume a fixed array count — always handle 0 to 6 results.

## Example

```swift
let swatches = try await image.labPalette(quality: .balanced, using: ScoredSwatchesTechnique(options: .init(candidateCount: 32)))

// Positional convention: Vibrant, LightVibrant, DarkVibrant, Muted, LightMuted, DarkMuted (subsequence, never padded)
// More robust: re-derive the category from HSL rather than trusting index alone.
if let vibrant = swatches.first(where: { ColorConverter.hsl(from: $0.rgb).saturation >= 0.35 }) {
    applyAccentColor(vibrant.rgb)
}
```
