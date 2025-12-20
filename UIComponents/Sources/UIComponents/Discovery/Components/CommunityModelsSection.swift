import Abstractions
import Kingfisher
import SwiftUI

/// A section view for displaying models grouped by community
internal struct CommunityModelsSection: View {
    // MARK: - Properties

    private let modelsByCommunity: [ModelCommunity: [DiscoveredModel]]

    // MARK: - Initialization

    init(
        modelsByCommunity: [ModelCommunity: [DiscoveredModel]]
    ) {
        self.modelsByCommunity = modelsByCommunity
    }

    // MARK: - Body

    var body: some View {
        if modelsByCommunity.isEmpty {
            emptyStateView
        } else {
            ScrollView {
                VStack(alignment: .leading, spacing: DesignConstants.Spacing.huge) {
                    ForEach(sortedCommunities, id: \.self) { community in
                        if let models = modelsByCommunity[community], !models.isEmpty {
                            communitySectionView(community: community, models: models)
                        }
                    }
                }
                .padding(.vertical)
            }
            .onAppear {
                prefetchCommunityImages()
            }
        }
    }

    // MARK: - Helper Methods

    /// Prefetches images for all community models to improve carousel performance
    private func prefetchCommunityImages() {
        let allModels: [DiscoveredModel] = modelsByCommunity.values.flatMap(\.self)
        let imageUrls: [URL] = allModels.compactMap { model in
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

    // MARK: - Computed Properties

    private var sortedCommunities: [ModelCommunity] {
        modelsByCommunity.keys.sorted { $0.displayName < $1.displayName }
    }

    // MARK: - Subviews

    private func communitySectionView(
        community: ModelCommunity,
        models: [DiscoveredModel]
    ) -> some View {
        VStack(alignment: .leading, spacing: DesignConstants.Spacing.large) {
            // Community header
            communityHeader(community)

            // Horizontal carousel
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
        }
    }

    private func communityHeader(_ community: ModelCommunity) -> some View {
        VStack(alignment: .leading, spacing: DesignConstants.Spacing.small) {
            communityHeaderTitle(community)
        }
        .padding(.horizontal, DesignConstants.Spacing.large)
    }

    private func communityHeaderTitle(_ community: ModelCommunity) -> some View {
        HStack {
            Image(systemName: communityIcon(for: community))
                .font(.title2)
                .foregroundColor(.marketingSecondary)
                .accessibilityHidden(true)

            VStack {
                Text(community.displayName)
                    .font(.title2)
                    .bold()
                    .foregroundColor(.textPrimary)

                if let description = community.description {
                    Text(description)
                        .font(.subheadline)
                        .foregroundColor(.textSecondary)
                }
            }
            Spacer()
        }
    }

    private func communityBackendTags(_ community: ModelCommunity) -> some View {
        HStack(spacing: DesignConstants.Spacing.small) {
            ForEach(community.supportedBackends, id: \.self) { backend in
                Text(backend.displayName)
                    .font(.caption2)
                    .foregroundColor(.white)
                    .padding(.horizontal, DesignConstants.Spacing.medium)
                    .padding(.vertical, DesignConstants.Spacing.small)
                    .background(
                        Capsule()
                            .fill(
                                Color.marketingSecondary.opacity(DesignConstants.Opacity.strong)
                            )
                    )
            }
        }
    }

    private var emptyStateView: some View {
        VStack(spacing: DesignConstants.Spacing.large) {
            Image(systemName: "network.slash")
                .font(.system(size: DesignConstants.Size.emptyStateIcon))
                .foregroundColor(.textSecondary)
                .accessibilityHidden(true)

            VStack(spacing: DesignConstants.Spacing.small) {
                Text("No community models available", bundle: .module)
                    .font(.headline)
                    .foregroundColor(.textPrimary)

                Text("Check your internet connection and try again", bundle: .module)
                    .font(.subheadline)
                    .foregroundColor(.textSecondary)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, DesignConstants.Spacing.huge)
    }

    // MARK: - Helper Methods

    private func communityIcon(for community: ModelCommunity) -> String {
        // Return appropriate icon based on community
        switch community.id {
        case "mlx-community":
            "cpu"

        case "lmstudio-community":
            "desktopcomputer"

        case "coreml-community":
            "square.stack.3d.up"

        default:
            "folder"
        }
    }
}

// MARK: - Preview

#if DEBUG
    #Preview("With Models") {
        ScrollView {
            CommunityModelsSection(
                modelsByCommunity: createPreviewModelsByCommunity()
            )
            .background(Color.backgroundPrimary)
        }
    }

    #Preview("Empty State") {
        CommunityModelsSection(
            modelsByCommunity: [:]
        )
        .background(Color.backgroundPrimary)
    }

    // Preview data
    private let kMlxCommunity: ModelCommunity = .init(
        id: "mlx-community",
        displayName: "MLX Community",
        supportedBackends: [.mlx],
        description: "Optimized models for Apple Silicon"
    )

    private let kCoremlCommunity: ModelCommunity = .init(
        id: "coreml-community",
        displayName: "Core ML Community",
        supportedBackends: [.coreml],
        description: "Models optimized for Core ML framework"
    )

    private struct MLXModelData {
        let id: String
        let name: String
        let downloads: Int
        let likes: Int
    }

    @MainActor
    private func createPreviewMlxModels() -> [DiscoveredModel] {
        let modelsData: [MLXModelData] = [
            MLXModelData(
                id: "mlx-community/model-1",
                name: "Llama-3.2-3B-Instruct",
                downloads: DiscoveryConstants.PreviewData.previewDownloads1,
                likes: DiscoveryConstants.PreviewData.previewLikes1
            ),
            MLXModelData(
                id: "mlx-community/model-2",
                name: "Mistral-7B-Instruct",
                downloads: DiscoveryConstants.PreviewData.previewDownloads2,
                likes: DiscoveryConstants.PreviewData.previewLikes2
            )
        ]

        return modelsData.map { data in
            let model: DiscoveredModel = DiscoveredModel(
                id: data.id,
                name: data.name,
                author: "mlx-community",
                downloads: data.downloads,
                likes: data.likes,
                tags: ["text-generation"],
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

    @MainActor
    private func createPreviewCoremlModels() -> [DiscoveredModel] {
        let model: DiscoveredModel = DiscoveredModel(
            id: "coreml-community/model-1",
            name: "Stable-Diffusion-v1.5",
            author: "coreml-community",
            downloads: DiscoveryConstants.PreviewData.previewDownloads3,
            likes: DiscoveryConstants.PreviewData.previewLikes3,
            tags: ["image-generation"],
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
            detectedBackends: [.coreml]
        )
        model.enrich(with: enrichedDetails)

        return [model]
    }

    @MainActor
    private func createPreviewModelsByCommunity() -> [ModelCommunity: [DiscoveredModel]] {
        [
            kMlxCommunity: createPreviewMlxModels(),
            kCoremlCommunity: createPreviewCoremlModels()
        ]
    }
#endif
