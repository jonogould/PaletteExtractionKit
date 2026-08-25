import Foundation

public typealias LabVector = SIMD3<Float>

public struct RGBColor: Sendable, Hashable {
    public var red: UInt8
    public var green: UInt8
    public var blue: UInt8
    public var alpha: UInt8

    public init(red: UInt8, green: UInt8, blue: UInt8, alpha: UInt8 = 255) {
        self.red = red
        self.green = green
        self.blue = blue
        self.alpha = alpha
    }

    public var hexString: String {
        String(format: "#%02X%02X%02X", red, green, blue)
    }
}

public struct LabColor: Sendable, Hashable {
    public var vector: LabVector

    public var l: Float { vector.x }
    public var a: Float { vector.y }
    public var b: Float { vector.z }

    public init(l: Float, a: Float, b: Float) {
        self.vector = LabVector(l, a, b)
    }

    public init(vector: LabVector) {
        self.vector = vector
    }

    public func deltaE76(to other: LabColor) -> Float {
        let delta = vector - other.vector
        return sqrtf(delta.x * delta.x + delta.y * delta.y + delta.z * delta.z)
    }

    public func deltaE2000(to other: LabColor) -> Float {
        // Sharma et al. CIEDE2000 implementation, using Float for SIMD-friendly pipelines.
        let kL: Float = 1
        let kC: Float = 1
        let kH: Float = 1
        let c1 = hypotf(a, b)
        let c2 = hypotf(other.a, other.b)
        let cBar = (c1 + c2) / 2
        let cBar7 = powf(cBar, 7)
        let g = 0.5 * (1 - sqrtf(cBar7 / (cBar7 + powf(25, 7))))
        let a1Prime = (1 + g) * a
        let a2Prime = (1 + g) * other.a
        let c1Prime = hypotf(a1Prime, b)
        let c2Prime = hypotf(a2Prime, other.b)

        func hue(_ aa: Float, _ bb: Float) -> Float {
            guard aa != 0 || bb != 0 else { return 0 }
            let h = atan2f(bb, aa) * 180 / .pi
            return h >= 0 ? h : h + 360
        }

        let h1Prime = hue(a1Prime, b)
        let h2Prime = hue(a2Prime, other.b)
        let deltaLPrime = other.l - l
        let deltaCPrime = c2Prime - c1Prime

        let deltahPrime: Float
        if c1Prime * c2Prime == 0 {
            deltahPrime = 0
        } else if abs(h2Prime - h1Prime) <= 180 {
            deltahPrime = h2Prime - h1Prime
        } else if h2Prime <= h1Prime {
            deltahPrime = h2Prime - h1Prime + 360
        } else {
            deltahPrime = h2Prime - h1Prime - 360
        }

        let deltaHPrime = 2 * sqrtf(c1Prime * c2Prime) * sinf((deltahPrime / 2) * .pi / 180)
        let lBarPrime = (l + other.l) / 2
        let cBarPrime = (c1Prime + c2Prime) / 2

        let hBarPrime: Float
        if c1Prime * c2Prime == 0 {
            hBarPrime = h1Prime + h2Prime
        } else if abs(h1Prime - h2Prime) <= 180 {
            hBarPrime = (h1Prime + h2Prime) / 2
        } else if h1Prime + h2Prime < 360 {
            hBarPrime = (h1Prime + h2Prime + 360) / 2
        } else {
            hBarPrime = (h1Prime + h2Prime - 360) / 2
        }

        let t = Float(1)
            - 0.17 * cosf((hBarPrime - 30) * .pi / 180)
            + 0.24 * cosf((2 * hBarPrime) * .pi / 180)
            + 0.32 * cosf((3 * hBarPrime + 6) * .pi / 180)
            - 0.20 * cosf((4 * hBarPrime - 63) * .pi / 180)

        let deltaTheta = 30 * expf(-powf((hBarPrime - 275) / 25, 2))
        let rC = 2 * sqrtf(powf(cBarPrime, 7) / (powf(cBarPrime, 7) + powf(25, 7)))
        let sL = 1 + (0.015 * powf(lBarPrime - 50, 2)) / sqrtf(20 + powf(lBarPrime - 50, 2))
        let sC = 1 + 0.045 * cBarPrime
        let sH = 1 + 0.015 * cBarPrime * t
        let rT = -sinf((2 * deltaTheta) * .pi / 180) * rC

        let lTerm = deltaLPrime / (kL * sL)
        let cTerm = deltaCPrime / (kC * sC)
        let hTerm = deltaHPrime / (kH * sH)

        return sqrtf(lTerm * lTerm + cTerm * cTerm + hTerm * hTerm + rT * cTerm * hTerm)
    }
}

public enum ColorConverter {
    public static func lab(from rgb: RGBColor) -> LabColor {
        let r = pivotSRGBToLinear(Float(rgb.red) / 255)
        let g = pivotSRGBToLinear(Float(rgb.green) / 255)
        let b = pivotSRGBToLinear(Float(rgb.blue) / 255)

        let x = r * 0.4124564 + g * 0.3575761 + b * 0.1804375
        let y = r * 0.2126729 + g * 0.7151522 + b * 0.0721750
        let z = r * 0.0193339 + g * 0.1191920 + b * 0.9503041

        let fx = pivotXYZToLab(x / 0.95047)
        let fy = pivotXYZToLab(y / 1.00000)
        let fz = pivotXYZToLab(z / 1.08883)

        return LabColor(
            l: max(0, 116 * fy - 16),
            a: 500 * (fx - fy),
            b: 200 * (fy - fz)
        )
    }

    public static func rgb(from lab: LabColor, alpha: UInt8 = 255) -> RGBColor {
        let fy = (lab.l + 16) / 116
        let fx = lab.a / 500 + fy
        let fz = fy - lab.b / 200

        let x = 0.95047 * pivotLabToXYZ(fx)
        let y = 1.00000 * pivotLabToXYZ(fy)
        let z = 1.08883 * pivotLabToXYZ(fz)

        let linearR = x * 3.2404542 + y * -1.5371385 + z * -0.4985314
        let linearG = x * -0.9692660 + y * 1.8760108 + z * 0.0415560
        let linearB = x * 0.0556434 + y * -0.2040259 + z * 1.0572252

        return RGBColor(
            red: toUInt8(pivotLinearToSRGB(linearR)),
            green: toUInt8(pivotLinearToSRGB(linearG)),
            blue: toUInt8(pivotLinearToSRGB(linearB)),
            alpha: alpha
        )
    }

    private static func pivotSRGBToLinear(_ value: Float) -> Float {
        value <= 0.04045 ? value / 12.92 : powf((value + 0.055) / 1.055, 2.4)
    }

    private static func pivotLinearToSRGB(_ value: Float) -> Float {
        let clamped = min(1, max(0, value))
        return clamped <= 0.0031308 ? 12.92 * clamped : 1.055 * powf(clamped, 1 / 2.4) - 0.055
    }

    private static func pivotXYZToLab(_ value: Float) -> Float {
        value > 0.008856 ? powf(value, 1 / 3) : (7.787 * value) + (16 / 116)
    }

    private static func pivotLabToXYZ(_ value: Float) -> Float {
        let cubed = value * value * value
        return cubed > 0.008856 ? cubed : (value - 16 / 116) / 7.787
    }

    private static func toUInt8(_ value: Float) -> UInt8 {
        UInt8(min(255, max(0, Int((value * 255).rounded()))))
    }
}
