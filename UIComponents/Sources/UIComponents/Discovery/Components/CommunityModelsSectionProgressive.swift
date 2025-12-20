import Abstractions
import SwiftUI

/// A progressive section view for displaying models grouped by community with per-community loading
internal struct CommunityModelsSectionProgressive: View {
    // MARK: - Constants

    private enum Constants {
        static let animationDuration: Double = 0.4
        static let scaleLoadingProgress: CGFloat = 0.8
        static let skeletonCardCount: Int = 3
        static let scaleTransitionScale: Double = 0.95
    }

    // MARK: - Properties

    private let modelsByCommunity: [ModelCommunity: [DiscoveredModel]]
    private let loadingStates: [ModelCommunity: Bool]

    // MARK: - Initialization

    init(
        modelsByCommunity: [ModelCommunity: [DiscoveredModel]],
        loadingStates: [ModelCommunity: Bool]
    ) {
        self.modelsByCommunity = modelsByCommunity
        self.loadingStates = loadingStates
    }

    // MARK: - Body

    var body: some View {
        if allCommunitiesEmpty, !isAnyLoading {
            emptyStateView
        } else {
            ScrollView {
                VStack(alignment: .leading, spacing: DesignConstants.Spacing.huge) {
                    ForEach(sortedCommunities, id: \.self) { community in
                        communitySectionView(community: community)
                    }
                }
                .padding(.vertical)
            }
        }
    }

    // MARK: - Computed Properties

    private var sortedCommunities: [ModelCommunity] {
        // Show all communities (both loading and loaded) in sorted order
        let allCommunities: Set<ModelCommunity> = Set(modelsByCommunity.keys).union(
            Set(loadingStates.keys)
        )
        return allCommunities.sorted { $0.displayName < $1.displayName }
    }

    private var allCommunitiesEmpty: Bool {
        modelsByCommunity.values.allSatisfy(\.isEmpty)
    }

    private var isAnyLoading: Bool {
        loadingStates.values.contains(true)
    }

    private func shouldShowCommunity(_ community: ModelCommunity) -> Bool {
        // Show if loading or has models
        let isLoading: Bool = loadingStates[community] == true
        let hasModels: Bool = modelsByCommunity[community]?.isEmpty == false
        return isLoading || hasModels
    }

    // MARK: - Subviews

    @ViewBuilder
    private func communitySectionView(community: ModelCommunity) -> some View {
        // Only show communities that are loading or have models
        if shouldShowCommunity(community) {
            VStack(alignment: .leading, spacing: DesignConstants.Spacing.large) {
                // Community header - visible when loading or has models
                communityHeader(community)

                // Content area - skeleton or models (never empty state)
                communityContent(community: community)
            }
        }
    }

    private func communityContent(community: ModelCommunity) -> some View {
        Group {
            if loadingStates[community] == true {
                // Show skeleton while loading this specific community
                communitySkeletonView()
                    .transition(
                        .opacity.combined(with: .scale(scale: Constants.scaleTransitionScale))
                    )
            } else if let models = modelsByCommunity[community], !models.isEmpty {
                // Show actual models with smooth transition
                communityModelsView(models: models)
                    .transition(
                        .opacity.combined(with: .scale(scale: Constants.scaleTransitionScale))
                    )
            }
            // Note: If community has finished loading but has no models, we don't show anything
            // This hides empty communities instead of showing "No models available"
        }
        .animation(
            .easeInOut(duration: Constants.animationDuration),
            value: loadingStates[community]
        )
        .animation(
            .easeInOut(duration: Constants.animationDuration),
            value: modelsByCommunity[community]?.count ?? 0
        )
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

            VStack(alignment: .leading) {
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

            // Loading indicator for this community
            if loadingStates[community] == true {
                ProgressView()
                    .scaleEffect(Constants.scaleLoadingProgress)
                    .accessibilityLabel("Loading \(community.displayName) models")
            }
        }
    }

    private func communityModelsView(models: [DiscoveredModel]) -> some View {
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

    private func communitySkeletonView() -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: DesignConstants.Spacing.large) {
                ForEach(0 ..< Constants.skeletonCardCount, id: \.self) { index in
                    ModelCardSkeleton(index: index)
                }
            }
            .padding(.horizontal, DesignConstants.Spacing.large)
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
    #Preview("Progressive Loading") {
        @Previewable @State var loadingStates: [ModelCommunity: Bool] = [
            kMlxCommunity: true,
            kCoremlCommunity: false
        ]

        @Previewable @State var modelsByCommunity: [ModelCommunity: [DiscoveredModel]] = [
            kCoremlCommunity: createPreviewCoremlModels()
        ]

        ScrollView {
            CommunityModelsSectionProgressive(
                modelsByCommunity: modelsByCommunity,
                loadingStates: loadingStates
            )
            .background(Color.backgroundPrimary)
        }
        .task {
            // Simulate progressive loading
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            loadingStates[kMlxCommunity] = false
            modelsByCommunity[kMlxCommunity] = createPreviewMlxModels()
        }
    }

    #Preview("All Loaded") {
        ScrollView {
            CommunityModelsSectionProgressive(
                modelsByCommunity: createPreviewModelsByCommunity(),
                loadingStates: [
                    kMlxCommunity: false,
                    kCoremlCommunity: false
                ]
            )
            .background(Color.backgroundPrimary)
        }
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

    @MainActor
    private func createPreviewMlxModels() -> [DiscoveredModel] {
        let model1: DiscoveredModel = DiscoveredModel(
            id: "mlx-community/model-1",
            name: "Llama-3.2-3B-Instruct",
            author: "mlx-community",
            downloads: DiscoveryConstants.PreviewData.previewDownloads1,
            likes: DiscoveryConstants.PreviewData.previewLikes1,
            tags: ["text-generation"],
            lastModified: Date(),
            files: [],
            license: nil,
            licenseUrl: nil,
            metadata: [:]
        )
        let enrichedDetails1: EnrichedModelDetails = EnrichedModelDetails(
            modelCard: nil,
            cardData: nil,
            imageUrls: [],
            detectedBackends: [.mlx]
        )
        model1.enrich(with: enrichedDetails1)

        let model2: DiscoveredModel = DiscoveredModel(
            id: "mlx-community/model-2",
            name: "Mistral-7B-Instruct",
            author: "mlx-community",
            downloads: DiscoveryConstants.PreviewData.previewDownloads2,
            likes: DiscoveryConstants.PreviewData.previewLikes2,
            tags: ["text-generation"],
            lastModified: Date(),
            files: [],
            license: nil,
            licenseUrl: nil,
            metadata: [:]
        )
        let enrichedDetails2: EnrichedModelDetails = EnrichedModelDetails(
            modelCard: nil,
            cardData: nil,
            imageUrls: [],
            detectedBackends: [.mlx]
        )
        model2.enrich(with: enrichedDetails2)

        return [model1, model2]
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
