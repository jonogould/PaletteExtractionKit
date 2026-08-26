# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project

PaletteExtractionDemo: Swift 6 / iOS 18 SwiftUI playground for perceptual color extraction from images. Lives at `demo/` inside the `PaletteExtractionKit` repo.

- `PaletteExtractionDemo/` — the entire app. `ContentView.swift` lets the user pick a photo via `PhotosPicker`, adjust the requested color count via a `Stepper`, and displays K-means and flood-fill palettes side by side.
- All extraction logic lives in **[PaletteExtractionKit](https://github.com/jonogould/PaletteExtractionKit)** — the standalone Swift package this demo sits alongside, pulled in as a **local** SPM dependency (see the `XCLocalSwiftPackageReference` in `PaletteExtractionDemo.xcodeproj/project.pbxproj`, `relativePath = ..`, pointing at the package root one directory up). It ships 10 built-in `PaletteExtractionTechnique` conformers; this app only wires up 2 of them (`KMeansTechnique`, `FloodFillTechnique`) — the rest are available but not yet exposed in this UI.

## Commands

Build/run: open `PaletteExtractionDemo.xcodeproj` in Xcode (16+), select `PaletteExtractionDemo` scheme, run on iOS 18 simulator/device. Prefer XcodeBuildMCP tools for build/test/run/log-capture over raw `xcodebuild`.

Because the package dependency is a local path reference (not a remote version pin), there is nothing to edit here to pick up changes to `PaletteExtractionKit` — the demo always builds against the current local source. Just re-resolve if Xcode's package cache goes stale: `xcodebuild -project PaletteExtractionDemo.xcodeproj -scheme PaletteExtractionDemo -resolvePackageDependencies`.

To change extraction behavior itself, work directly in `../Sources/PaletteExtractionKit/` — there's nothing to edit in this demo for that.

## Architecture

`ContentView.swift` is the only real file. It calls `UIImage.labPalettes(quality:using:)` (from `PaletteExtractionKit`) with an explicit `[KMeansTechnique, FloodFillTechnique]` list to get both techniques' output at once, and renders each as a `PaletteSection` of circular swatches with hex labels below them. `PhotosPicker` selection drives a `.task(id: selectedItem)` that loads the image data, converts to `UIImage`, and kicks off extraction (`loadSelectedImage()` → `extractPalettes()`); a separate `.task(id: paletteCount)` re-runs `extractPalettes()` on the already-decoded image when the `Stepper` changes, without re-downloading/re-decoding the photo.

For how the palette extraction itself works (the 10 techniques, L*a*b* color math, concurrency model, the `PaletteExtractionTechnique` protocol), see the `PaletteExtractionKit` repo's own README (one directory up) and its per-technique docs under `../Sources/PaletteExtractionKit/Techniques/<Name>/README.md` — don't duplicate that documentation here since it'll drift.
