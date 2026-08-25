import Foundation

public struct HSLColor: Sendable {
    public let hue: Float
    public let saturation: Float
    public let lightness: Float

    public init(hue: Float, saturation: Float, lightness: Float) {
        self.hue = hue
        self.saturation = saturation
        self.lightness = lightness
    }
}

public extension ColorConverter {
    static func hsl(from rgb: RGBColor) -> HSLColor {
        let r = Float(rgb.red) / 255
        let g = Float(rgb.green) / 255
        let b = Float(rgb.blue) / 255

        let maxValue = max(r, g, b)
        let minValue = min(r, g, b)
        let delta = maxValue - minValue
        let lightness = (maxValue + minValue) / 2

        guard delta > 0 else {
            return HSLColor(hue: 0, saturation: 0, lightness: lightness)
        }

        let saturation = delta / (1 - abs(2 * lightness - 1))

        var hue: Float
        if maxValue == r {
            hue = ((g - b) / delta).truncatingRemainder(dividingBy: 6)
        } else if maxValue == g {
            hue = (b - r) / delta + 2
        } else {
            hue = (r - g) / delta + 4
        }
        hue *= 60
        if hue < 0 { hue += 360 }

        return HSLColor(hue: hue, saturation: saturation, lightness: lightness)
    }
}
