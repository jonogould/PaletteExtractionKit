import SwiftUI
import PhotosUI
import PaletteExtractionKit

struct ContentView: View {
    @State private var selectedItem: PhotosPickerItem?
    @State private var selectedImage: UIImage?
    @State private var results: [ExtractedPalette] = []
    @State private var isExtracting = false
    @State private var errorMessage: String?
    @State private var paletteCount = 4
    @State private var selectedTechniqueNames: Set<String> = ["K-means", "Flood fill"]

    // The two defaults (matching selectedTechniqueNames below) lead the list, then the
    // rest are ordered by popularity first, ease of implementation as a tiebreaker.
    private let allTechniques: [any PaletteExtractionTechnique] = [
        KMeansTechnique(),             // Default-selected
        FloodFillTechnique(),          // Default-selected
        ModifiedMedianCutTechnique(),  // Highest popularity (color-thief), moderate ease
        ScoredSwatchesTechnique(),     // Highest popularity (Android Palette), harder ease
        MedianCutTechnique(),          // Medium-high popularity
        AverageColorTechnique(),       // Medium popularity, trivial ease
        OctreeQuantizationTechnique(), // Medium popularity, moderate-hard ease
        WuQuantizationTechnique(),     // Medium popularity, hardest ease
        AgglomerativeTechnique(),      // Low-medium popularity
        HistogramTechnique()           // Low popularity
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 28) {
                    imagePickerCard

                    if isExtracting {
                        ProgressView("Extracting palettes…")
                            .frame(maxWidth: .infinity)
                    }

                    ForEach(results) { result in
                        PaletteSection(title: result.name, subtitle: result.description, palette: result.colors)
                    }

                    if selectedTechniqueNames.isEmpty {
                        Text("Select at least one technique to extract a palette.")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }

                    if let errorMessage {
                        Text(errorMessage)
                            .font(.callout)
                            .foregroundStyle(.red)
                            .multilineTextAlignment(.center)
                    }
                }
                .padding(24)
            }
            .navigationTitle("PaletteExtractionKit")
            .task(id: selectedItem) {
                await loadSelectedImage()
            }
            .task(id: paletteCount) {
                await extractPalettes()
            }
            .task(id: selectedTechniqueNames) {
                await extractPalettes()
            }
        }
    }

    private var imagePickerCard: some View {
        VStack(spacing: 16) {
            Group {
                if let selectedImage {
                    Image(uiImage: selectedImage)
                        .resizable()
                        .scaledToFit()
                } else {
                    ContentUnavailableView(
                        "Choose an Image",
                        systemImage: "photo.on.rectangle.angled",
                        description: Text("Pick a photo to compare palettes across extraction techniques.")
                    )
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 320)
            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
            .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))

            PhotosPicker(selection: $selectedItem, matching: .images) {
                Label(selectedImage == nil ? "Upload Image" : "Choose Another Image", systemImage: "photo.badge.plus")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)

            Stepper("Colors to extract: \(paletteCount)", value: $paletteCount, in: 1...Int.max)

            techniquePicker
        }
    }

    private var techniquePicker: some View {
        FlowLayout(spacing: 8) {
            ForEach(allTechniques, id: \.name) { technique in
                let isSelected = selectedTechniqueNames.contains(technique.name)
                Button {
                    if isSelected {
                        selectedTechniqueNames.remove(technique.name)
                    } else {
                        selectedTechniqueNames.insert(technique.name)
                    }
                } label: {
                    Text(technique.name)
                        .font(.subheadline.weight(.medium))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(isSelected ? Color.accentColor : Color(uiColor: .secondarySystemBackground), in: Capsule())
                        .foregroundStyle(isSelected ? Color.white : Color.primary)
                }
                .buttonStyle(.plain)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @MainActor
    private func loadSelectedImage() async {
        guard let selectedItem else { return }

        errorMessage = nil
        results = []

        do {
            guard let data = try await selectedItem.loadTransferable(type: Data.self),
                  let image = UIImage(data: data) else {
                throw PlaygroundError.couldNotLoadImage
            }
            selectedImage = image
        } catch {
            errorMessage = error.localizedDescription
            return
        }

        await extractPalettes()
    }

    @MainActor
    private func extractPalettes() async {
        guard let selectedImage else { return }

        let techniques = selectedTechniques
        guard !techniques.isEmpty else {
            results = []
            return
        }

        isExtracting = true
        errorMessage = nil

        do {
            results = try await selectedImage.labPalettes(quality: .balanced, using: techniques)
        } catch {
            errorMessage = error.localizedDescription
        }

        isExtracting = false
    }

    private var selectedTechniques: [any PaletteExtractionTechnique] {
        allTechniques
            .map(\.name)
            .filter { selectedTechniqueNames.contains($0) }
            .map(makeTechnique(named:))
    }

    private func makeTechnique(named name: String) -> any PaletteExtractionTechnique {
        switch name {
        case "K-means":
            KMeansTechnique(options: .init(colorCount: paletteCount))
        case "Flood fill":
            FloodFillTechnique(options: .init(colorCount: paletteCount))
        case "Median cut":
            MedianCutTechnique(options: .init(colorCount: paletteCount))
        case "MMCQ":
            ModifiedMedianCutTechnique(options: .init(colorCount: paletteCount))
        case "Wu quantization":
            WuQuantizationTechnique(options: .init(colorCount: paletteCount))
        case "Octree quantization":
            OctreeQuantizationTechnique(options: .init(colorCount: paletteCount))
        case "Histogram":
            HistogramTechnique(options: .init(colorCount: paletteCount))
        case "Agglomerative":
            AgglomerativeTechnique(options: .init(colorCount: paletteCount))
        case "Average color":
            AverageColorTechnique()
        default:
            ScoredSwatchesTechnique()
        }
    }
}

/// Wraps subviews left-to-right, moving to a new line whenever the next one would
/// overflow the available width — a "flow"/"tag cloud" layout with no scrolling needed.
private struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var rowWidth: CGFloat = 0
        var rowHeight: CGFloat = 0
        var totalWidth: CGFloat = 0
        var totalHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if rowWidth > 0, rowWidth + spacing + size.width > maxWidth {
                totalHeight += rowHeight + spacing
                totalWidth = max(totalWidth, rowWidth)
                rowWidth = 0
                rowHeight = 0
            }
            rowWidth += (rowWidth > 0 ? spacing : 0) + size.width
            rowHeight = max(rowHeight, size.height)
        }
        totalHeight += rowHeight
        totalWidth = max(totalWidth, rowWidth)

        return CGSize(width: proposal.width ?? totalWidth, height: totalHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX
        var y = bounds.minY
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x > bounds.minX, x + size.width > bounds.maxX {
                x = bounds.minX
                y += rowHeight + spacing
                rowHeight = 0
            }
            subview.place(at: CGPoint(x: x, y: y), anchor: .topLeading, proposal: .unspecified)
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}

private struct PaletteSection: View {
    let title: String
    let subtitle: String
    let palette: [PaletteColor]

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.title2.bold())

                if !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 14) {
                    ForEach(Array(palette.enumerated()), id: \.offset) { _, color in
                        VStack(spacing: 8) {
                            Circle()
                                .fill(Color(uiColor: color.uiColor))
                                .frame(width: 58, height: 58)
                                .shadow(radius: 3, y: 2)

                            Text(color.hex)
                                .font(.caption2.monospaced())
                                .lineLimit(1)
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private enum PlaygroundError: LocalizedError {
    case couldNotLoadImage

    var errorDescription: String? {
        "Could not load that image. Try another photo."
    }
}

#Preview {
    ContentView()
}
