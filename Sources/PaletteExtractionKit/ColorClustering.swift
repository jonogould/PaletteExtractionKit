import Foundation

enum ColorClustering {
    static func distance(_ x: LabColor, _ y: LabColor, method: DeltaEMethod) -> Float {
        switch method {
        case .deltaE76: x.deltaE76(to: y)
        case .deltaE2000: x.deltaE2000(to: y)
        }
    }

    static func mergeSimilar(_ colors: [PaletteColor], threshold: Float, method: DeltaEMethod) -> [PaletteColor] {
        guard threshold > 0 else { return colors }
        var merged: [PaletteColor] = []

        for color in colors {
            if let index = merged.firstIndex(where: { distance($0.lab, color.lab, method: method) <= threshold }) {
                let existing = merged[index]
                let total = existing.population + color.population
                let vector = ((existing.lab.vector * Float(existing.population)) + (color.lab.vector * Float(color.population))) / Float(total)
                let lab = LabColor(vector: vector)
                merged[index] = PaletteColor(
                    rgb: ColorConverter.rgb(from: lab),
                    lab: lab,
                    population: total,
                    percentage: existing.percentage + color.percentage
                )
            } else {
                merged.append(color)
            }
        }

        return merged.sorted { $0.population > $1.population }
    }
}
