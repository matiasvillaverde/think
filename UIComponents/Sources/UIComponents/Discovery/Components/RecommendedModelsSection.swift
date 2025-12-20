import Abstractions
import Kingfisher
import SwiftUI

/// A section view for displaying recommended models
internal struct RecommendedModelsSection: View {
    // MARK: - Properties

    private let models: [DiscoveredModel]

    // MARK: - Initialization

    init(
        models: [DiscoveredModel],
    ) {
        self.models = models
    }

    // MARK: - Body

    var body: some View {
        VStack(alignment: .leading, spacing: DesignConstants.Spacing.large) {
            // Section header
            sectionHeader

            if models.isEmpty {
                emptyStateView
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: DesignConstants.Spacing.large) {
                        ForEach(models) { model in
                            NavigationLink(value: model) {
                                DiscoveryModelCard(model: model)
                            }
                            .buttonStyle(DiscoveryModelCardButtonStyle())
                        }
                    }
                    .padding(.horizontal, DesignConstants.Spacing.large)
                }
                .onAppear {
                    prefetchRecommendedImages()
                }
            }
        }
    }

    // MARK: - Helper Methods

    /// Prefetches images for recommended models to improve carousel performance
    private func prefetchRecommendedImages() {
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

    private var sectionHeader: some View {
        VStack(alignment: .leading, spacing: DesignConstants.Spacing.small) {
            HStack {
                Image(systemName: "sparkles")
                    .font(.title2)
                    .foregroundColor(.marketingSecondary)
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: DesignConstants.Spacing.small) {
                    Text("Recommended for You", bundle: .module)
                        .font(.title2)
                        .bold()
                        .foregroundColor(.textPrimary)

                    Text("Models compatible with your device", bundle: .module)
                        .font(.subheadline)
                        .foregroundColor(.textSecondary)
                }
                Spacer()
            }
        }
        .padding(.horizontal, DesignConstants.Spacing.large)
    }

    private var emptyStateView: some View {
        VStack(spacing: DesignConstants.Spacing.large) {
            Image(systemName: "exclamationmark.circle")
                .font(.system(size: DesignConstants.Size.emptyStateIcon))
                .foregroundColor(.textSecondary)
                .accessibilityHidden(true)

            VStack(spacing: DesignConstants.Spacing.small) {
                Text("No compatible models found", bundle: .module)
                    .font(.headline)
                    .foregroundColor(.textPrimary)

                Text(
                    "Your device may not have enough memory for the available models",
                    bundle: .module
                )
                .font(.subheadline)
                .foregroundColor(.textSecondary)
                .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, DesignConstants.Spacing.huge)
        .padding(.horizontal, DesignConstants.Spacing.large)
    }
}

// MARK: - Preview

#if DEBUG
    private struct PreviewModelData {
        let id: String
        let name: String
        let downloads: Int
        let likes: Int
        let tags: [String]
    }

    @MainActor
    private func createPreviewRecommendedModels() -> [DiscoveredModel] {
        let modelDataItems: [PreviewModelData] = [
            PreviewModelData(
                id: "model-1",
                name: "Llama-3.2-3B-Instruct-4bit",
                downloads: DiscoveryConstants.PreviewData.previewDownloads1,
                likes: DiscoveryConstants.PreviewData.previewLikes1,
                tags: ["text-generation", "llama"]
            ),
            PreviewModelData(
                id: "model-2",
                name: "Mistral-7B-Instruct-v0.3",
                downloads: DiscoveryConstants.PreviewData.previewDownloads2,
                likes: DiscoveryConstants.PreviewData.previewLikes2,
                tags: ["text-generation", "mistral"]
            ),
            PreviewModelData(
                id: "model-3",
                name: "Phi-3-mini-4k",
                downloads: DiscoveryConstants.PreviewData.previewDownloads3,
                likes: DiscoveryConstants.PreviewData.previewLikes3,
                tags: ["text-generation", "phi"]
            )
        ]

        return createModelsFromData(modelDataItems)
    }

    @MainActor
    private func createModelsFromData(_ modelDataItems: [PreviewModelData]) -> [DiscoveredModel] {
        modelDataItems.map { modelData in
            let model: DiscoveredModel = DiscoveredModel(
                id: modelData.id,
                name: modelData.name,
                author: "mlx-community",
                downloads: modelData.downloads,
                likes: modelData.likes,
                tags: modelData.tags,
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
                detectedBackends: [.mlx]
            )
            model.enrich(with: enrichedDetails)

            return model
        }
    }

    #Preview("With Models") {
        RecommendedModelsSection(
            models: createPreviewRecommendedModels()
        )
        .background(Color.backgroundPrimary)
    }

    #Preview("Empty State") {
        RecommendedModelsSection(
            models: []
        )
        .background(Color.backgroundPrimary)
    }
#endif
