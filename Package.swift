// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PaletteExtractionKit",
    platforms: [
        .iOS(.v18),
        .macOS(.v15)
    ],
    products: [
        .library(name: "PaletteExtractionKit", targets: ["PaletteExtractionKit"])
    ],
    targets: [
        .target(
            name: "PaletteExtractionKit",
            swiftSettings: [
                .enableExperimentalFeature("StrictConcurrency")
            ]
        ),
        .testTarget(name: "PaletteExtractionKitTests", dependencies: ["PaletteExtractionKit"])
    ]
)
