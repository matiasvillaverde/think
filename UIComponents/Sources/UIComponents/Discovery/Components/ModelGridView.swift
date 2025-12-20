import Abstractions
import Kingfisher
import SwiftUI

/// A grid view for displaying discovered models
internal struct ModelGridView: View {
    // MARK: - Properties

    private let models: [DiscoveredModel]

    // MARK: - Grid Configuration

    private let columns: [GridItem] = [
        GridItem(
            .adaptive(minimum: DiscoveryConstants.Card.width),
            spacing: DesignConstants.Spacing.large
        )
    ]

    // MARK: - Initialization

    init(
        models: [DiscoveredModel]
    ) {
        self.models = models
    }

    // MARK: - Body

    var body: some View {
        if models.isEmpty {
            emptyStateView
        } else {
            LazyVGrid(columns: columns, spacing: DesignConstants.Spacing.large) {
                ForEach(models) { model in
                    DiscoveryModelCard(model: model)
                }
            }
            .onAppear {
                prefetchVisibleImages()
            }
        }
    }

    // MARK: - Helper Methods

    /// Prefetches images for visible models to improve performance
    private func prefetchVisibleImages() {
        let imageUrls: [URL] = models.compactMap { model in
            // Get primary image URL using same logic as DiscoveryModelCard
            if !model.imageUrls.isEmpty,
                let firstUrl = model.imageUrls.first,
                let url = URL(string: firstUrl) {
                return url
            }

            if let thumbnail = model.cardData?.thumbnail,
                let url = URL(string: thumbnail) {
                return url
            }

            return nil
        }

        // Prefetch with card-optimized size
        ImageLoader.shared.prefetchImages(
            urls: imageUrls,
            targetSize: DiscoveryConstants.Card.imageSize
        )
    }

    // MARK: - Subviews

    private var emptyStateView: some View {
        VStack(spacing: DesignConstants.Spacing.large) {
            Image(systemName: "square.stack.3d.up.slash")
                .font(.system(size: DesignConstants.Size.emptyStateIcon))
                .foregroundColor(.textSecondary)
                .accessibilityHidden(true)

            Text("No models found", bundle: .module)
                .font(.headline)
                .foregroundColor(.textPrimary)

            Text("Try adjusting your filters", bundle: .module)
                .font(.subheadline)
                .foregroundColor(.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, DesignConstants.Spacing.huge)
    }
}

// MARK: - Preview

#if DEBUG
    #Preview("Grid with Models") {
        ScrollView {
            ModelGridView(
                models: getPreviewModels()
            )
            .padding()
        }
        .background(Color.backgroundPrimary)
    }

    #Preview("Empty State") {
        ModelGridView(
            models: []
        )
        .padding()
        .background(Color.backgroundPrimary)
    }

    // Preview data
    private struct GridModelData {
        let id: String
        let name: String
        let author: String
        let downloads: Int
        let likes: Int
        let tags: [String]
        let backend: SendableModel.Backend
    }

    private func createGridModelData() -> [GridModelData] {
        [
            GridModelData(
                id: "model-1",
                name: "Llama-3.2-3B-Instruct",
                author: "mlx-community",
                downloads: DiscoveryConstants.PreviewData.previewDownloads1,
                likes: DiscoveryConstants.PreviewData.previewLikes1,
                tags: ["text-generation"],
                backend: .mlx
            ),
            GridModelData(
                id: "model-2",
                name: "Mistral-7B-Instruct",
                author: "mlx-community",
                downloads: DiscoveryConstants.PreviewData.previewDownloads2,
                likes: DiscoveryConstants.PreviewData.previewLikes2,
                tags: ["text-generation"],
                backend: .mlx
            ),
            GridModelData(
                id: "model-3",
                name: "StableDiffusion-v1.5",
                author: "coreml-community",
                downloads: DiscoveryConstants.PreviewData.previewDownloads3,
                likes: DiscoveryConstants.PreviewData.previewLikes3,
                tags: ["image-generation"],
                backend: .coreml
            ),
            GridModelData(
                id: "model-4",
                name: "Phi-3-mini",
                author: "lmstudio-community",
                downloads: DiscoveryConstants.PreviewData.previewDownloads4,
                likes: DiscoveryConstants.PreviewData.previewLikes4,
                tags: ["text-generation"],
                backend: .gguf
            )
        ]
    }

    @MainActor
    private func createPreviewGridModels() -> [DiscoveredModel] {
        let modelData: [GridModelData] = createGridModelData()

        return modelData.map { data in
            let model: DiscoveredModel = DiscoveredModel(
                id: data.id,
                name: data.name,
                author: data.author,
                downloads: data.downloads,
                likes: data.likes,
                tags: data.tags,
                lastModified: Date(),
                files: [],
                license: nil,
                licenseUrl: nil,
                metadata: [:]
            )

            let enrichedDetails: EnrichedModelDetails = EnrichedModelDetails(
                modelCard: nil,
                cardData: nil,
                imageUrls: [],
                detectedBackends: [data.backend]
            )
            model.enrich(with: enrichedDetails)

            return model
        }
    }

    @MainActor
    private func getPreviewModels() -> [DiscoveredModel] {
        createPreviewGridModels()
    }
#endif
