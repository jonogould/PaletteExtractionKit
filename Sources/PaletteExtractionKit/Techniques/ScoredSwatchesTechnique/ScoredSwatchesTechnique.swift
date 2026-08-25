import Foundation

public struct ScoredSwatchesOptions: Sendable {
    public var quality: PaletteQuality
    public var minimumAlpha: UInt8
    /// Granularity fed into the internal quantizer stage before scoring — NOT a
    /// swatch-count knob. This technique always returns 0–6 semantic swatches.
    public var candidateCount: Int

    public init(quality: PaletteQuality = .balanced, minimumAlpha: UInt8 = 128, candidateCount: Int = 24) {
        self.quality = quality
        self.minimumAlpha = minimumAlpha
        self.candidateCount = max(6, candidateCount)
    }
}

/// Android `androidx.palette`-style semantic swatches. Scores candidates against 6 fixed
/// target bands (saturation/luma) instead of returning a plain top-N palette.
///
/// Output order is fixed and documented, always a subsequence of
/// `[Vibrant, LightVibrant, DarkVibrant, Muted, LightMuted, DarkMuted]` in that relative
/// order — never reordered by score. `PaletteColor` has no label field, so a slot's
/// identity is positional-by-convention; identify one by its measured HSL properties
/// (via `ColorConverter.hsl(from:)`) rather than by array index alone.
///
/// The scoring constants are approximated from `androidx.palette`'s published source, not
/// verified byte-exact against current AOSP — expect plausible Vibrant/Muted behavior, not
/// a certified match to real Android output.
public struct ScoredSwatchesTechnique: PaletteExtractionTechnique {
    public var name: String { "Scored swatches" }
    public var description: String { "Vibrant/muted swatches, Android Palette-style" }
    public var options: ScoredSwatchesOptions

    public init(options: ScoredSwatchesOptions = .init()) {
        self.options = options
    }

    public func extract(from image: PixelImage) async -> [PaletteColor] {
        await Self.extractAsync(from: image.pixels, options: options)
    }

    public static func extract(from pixels: [RGBColor], options: ScoredSwatchesOptions = .init()) -> [PaletteColor] {
        let filtered = pixels.filter { $0.alpha >= options.minimumAlpha }
        guard !filtered.isEmpty else { return [] }
        let sampled = strideSample(filtered, limit: options.quality.maxSamples)

        let boxes = MedianCutQuantizer.quantize(pixels: sampled, targetBoxCount: options.candidateCount)
        guard !boxes.isEmpty else { return [] }

        let candidates = boxes.map { box in (rgb: box.rgb, hsl: ColorConverter.hsl(from: box.rgb), population: box.population) }
        let maxPopulation = candidates.map(\.population).max() ?? 0
        let totalPopulation = candidates.reduce(0) { $0 + $1.population }
        guard totalPopulation > 0 else { return [] }

        var results: [PaletteColor] = []
        for target in swatchTargets {
            var bestScore = -Float.infinity
            var best: (rgb: RGBColor, population: Int)?

            for candidate in candidates {
                guard let s = score(hsl: candidate.hsl, population: candidate.population, target: target, maxPopulation: maxPopulation) else { continue }
                if s > bestScore {
                    bestScore = s
                    best = (candidate.rgb, candidate.population)
                }
            }

            if let best {
                let lab = ColorConverter.lab(from: best.rgb)
                results.append(PaletteColor(rgb: best.rgb, lab: lab, population: best.population, percentage: Float(best.population) / Float(totalPopulation)))
            }
        }

        return results
    }

    public static func extractAsync(from pixels: [RGBColor], options: ScoredSwatchesOptions = .init()) async -> [PaletteColor] {
        await Task.detached(priority: .userInitiated) {
            extract(from: pixels, options: options)
        }.value
    }

    private struct SwatchTarget {
        let lumaTarget: Float
        let lumaMin: Float
        let lumaMax: Float
        let saturationTarget: Float
        let saturationMin: Float
        let saturationMax: Float
    }

    // Vibrant, LightVibrant, DarkVibrant, Muted, LightMuted, DarkMuted — in this fixed order.
    private static let swatchTargets: [SwatchTarget] = [
        SwatchTarget(lumaTarget: 0.50, lumaMin: 0.30, lumaMax: 0.70, saturationTarget: 1.0, saturationMin: 0.35, saturationMax: 1.0),
        SwatchTarget(lumaTarget: 0.74, lumaMin: 0.55, lumaMax: 1.00, saturationTarget: 1.0, saturationMin: 0.35, saturationMax: 1.0),
        SwatchTarget(lumaTarget: 0.26, lumaMin: 0.00, lumaMax: 0.45, saturationTarget: 1.0, saturationMin: 0.35, saturationMax: 1.0),
        SwatchTarget(lumaTarget: 0.50, lumaMin: 0.30, lumaMax: 0.70, saturationTarget: 0.3, saturationMin: 0.00, saturationMax: 0.4),
        SwatchTarget(lumaTarget: 0.74, lumaMin: 0.55, lumaMax: 1.00, saturationTarget: 0.3, saturationMin: 0.00, saturationMax: 0.4),
        SwatchTarget(lumaTarget: 0.26, lumaMin: 0.00, lumaMax: 0.45, saturationTarget: 0.3, saturationMin: 0.00, saturationMax: 0.4)
    ]

    private static func score(hsl: HSLColor, population: Int, target: SwatchTarget, maxPopulation: Int) -> Float? {
        guard hsl.saturation >= target.saturationMin, hsl.saturation <= target.saturationMax,
              hsl.lightness >= target.lumaMin, hsl.lightness <= target.lumaMax else {
            return nil
        }
        let saturationScore = 1 - abs(hsl.saturation - target.saturationTarget)
        let lumaScore = 1 - abs(hsl.lightness - target.lumaTarget)
        let populationScore = maxPopulation > 0 ? Float(population) / Float(maxPopulation) : 0
        return 3 * saturationScore + 6 * lumaScore + 1 * populationScore
    }

    private static func strideSample<T>(_ input: [T], limit: Int) -> [T] {
        guard input.count > limit else { return input }
        let step = Double(input.count) / Double(limit)
        return (0..<limit).map { input[Int(Double($0) * step)] }
    }
}
