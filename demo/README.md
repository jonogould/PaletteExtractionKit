# PaletteExtractionDemo

A small Swift 6 / iOS 18 SwiftUI project for experimenting with perceptual color extraction.

This demo lives at `demo/` inside the [`PaletteExtractionKit`](https://github.com/jonogould/PaletteExtractionKit) repo and depends on the package via a local path reference — not a remote version pin — so it always builds against the current local source.

## What it includes

- `PaletteExtractionDemo.xcodeproj` — iOS app project
- `PaletteExtractionDemo` — SwiftUI playground UI
- `PaletteExtractionKit` — local SPM dependency (the package one directory up) for palette extraction
- K-means in L*a*b* space with Delta-E distances
- Flood-fill / connected-region palette extraction
- Runs both algorithms on image upload and shows 4 circular swatches per algorithm

## How to run

1. Open `PaletteExtractionDemo.xcodeproj` in Xcode 16 or newer.
2. Select the `PaletteExtractionDemo` scheme.
3. Run on an iOS 18 simulator or device.
4. Tap **Upload Image** and choose a photo.

The app will show two palettes: K-means LAB and Flood fill.
