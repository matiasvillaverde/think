import Abstractions
import SwiftUI

/// A discovery view for browsing and filtering AI models with progressive loading
internal struct DiscoveryCarouselView: View {
    // MARK: - Constants

    private enum Constants {
        static let animationDuration: Double = 0.3
        static let pickerWidth: CGFloat = 300
    }

    // MARK: - Environment

    @Environment(\.discoveryCarousel)
    private var viewModel: DiscoveryCarouselViewModeling

    // MARK: - State

    @State private var recommendedModels: [DiscoveredModel] = []
    @State private var communityModels: [ModelCommunity: [DiscoveredModel]] = [:]
    @State private var communitiesLoadingStates: [ModelCommunity: Bool] = [:]
    @State private var isLoadingRecommended: Bool = true
    @State private var isLoadingCommunity: Bool = true
    @State private var recommendedError: Error?
    @State private var communityError: Error?
    @State private var selectedFilter: ModelTypeFilter = .text
    @State private var hasLoadedOnce: Bool = false

    internal init() {
        // Initialize view with empty state
    }

    // MARK: - Computed Properties

    private var filteredRecommendedModels: [DiscoveredModel] {
        recommendedModels.filter { selectedFilter.matches($0) }
    }

    private var filteredCommunityModels: [ModelCommunity: [DiscoveredModel]] {
        communityModels
            .mapValues { models in
                models.filter { selectedFilter.matches($0) }
            }
            .filter { !$0.value.isEmpty }
    }

    // MARK: - Body

    internal var body: some View {
        VStack(spacing: 0) {
            mainContent
        }
        .animation(.smooth, value: selectedFilter)
        #if os(macOS)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Picker("Model Type", selection: $selectedFilter) {
                    ForEach(ModelTypeFilter.allCases) { filter in
                        Label(filter.displayName, systemImage: filter.iconName)
                            .tag(filter)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: Constants.pickerWidth)
                .help("Filter models by type")
            }
        }
        #endif
        .task {
            // Only load once to prevent reloading on every view appearance (fixes issue line 44-45)
            if !hasLoadedOnce {
                hasLoadedOnce = true
                await loadModelsProgressive()
            }
        }
    }

    // MARK: - Subviews

    private var mainContent: some View {
        VStack(spacing: DesignConstants.Spacing.large) {
            // Search bar for finding any HuggingFace model
            DiscoverySearchBar()
                .padding(.horizontal)
                .padding(.top, DesignConstants.Spacing.medium)

            // Filter bar - only show on non-macOS platforms
            #if !os(macOS)
            ModelTypeFilterBar(selection: $selectedFilter)
            #endif

            ScrollView(.vertical, showsIndicators: true) {
                VStack(alignment: .leading, spacing: DesignConstants.Spacing.huge) {
                    // Recommended models section - loads independently
                    recommendedSection

                    // Community models section - loads independently
                    communitySection
                }
                .padding(.vertical, DesignConstants.Spacing.large)
            }
        }
    }

    private var recommendedSection: some View {
        Group {
            if isLoadingRecommended {
                // Skeleton loading for recommended section
                RecommendedModelsSectionSkeleton()
            } else if let error = recommendedError {
                // Error state for recommended section
                sectionErrorView(error, section: "Recommended") {
                    Task { await loadRecommendedModels() }
                }
            } else if !filteredRecommendedModels.isEmpty {
                // Actual content when loaded
                RecommendedModelsSection(
                    models: filteredRecommendedModels
                )
            }
        }
    }

    private var communitySection: some View {
        Group {
            if let error = communityError {
                // Error state for community section
                sectionErrorView(error, section: "Community") {
                    Task { await loadCommunityModelsProgressive() }
                }
            } else {
                // Progressive community content with per-community loading states
                CommunityModelsSectionProgressive(
                    modelsByCommunity: filteredCommunityModels,
                    loadingStates: communitiesLoadingStates
                )
            }
        }
    }

    private func sectionErrorView(
        _: Error,
        section: String,
        retry: @escaping () -> Void
    ) -> some View {
        VStack(spacing: DesignConstants.Spacing.medium) {
            HStack {
                Image(systemName: "exclamationmark.triangle")
                    .foregroundColor(.iconAlert)
                    .accessibilityHidden(true)

                Text("Failed to load \(section) models", bundle: .module)
                    .font(.subheadline)
                    .foregroundColor(.textSecondary)

                Spacer()

                Button(action: retry) {
                    Label(
                        String(localized: "Retry", bundle: .module),
                        systemImage: "arrow.clockwise"
                    )
                    .font(.caption)
                }
                .buttonStyle(.bordered)
            }
            .padding(.horizontal, DesignConstants.Spacing.large)
        }
    }

    // MARK: - Progressive Data Loading

    private func loadModelsProgressive() async {
        // Load sections independently
        await withTaskGroup(of: Void.self) { group in
            group.addTask {
                await loadRecommendedModels()
            }
            group.addTask {
                await loadCommunityModelsProgressive()
            }
        }
    }

    private func loadRecommendedModels() async {
        isLoadingRecommended = true
        recommendedError = nil

        do {
            recommendedModels = try await viewModel.recommendedAllModels()
        } catch {
            recommendedError = error
        }

        isLoadingRecommended = false
    }

    private func loadCommunityModelsProgressive() async {
        // Initialize loading states for all communities
        let defaultCommunities: [ModelCommunity] = await viewModel
            .getDefaultCommunitiesFromProtocol()
        await MainActor.run {
            for community in defaultCommunities {
                communitiesLoadingStates[community] = true
            }
        }

        communityError = nil

        // Use progressive loading stream to update UI as each community loads
        let progressiveStream: AsyncStream<(ModelCommunity, [DiscoveredModel])> = await viewModel
            .latestModelsFromDefaultCommunitiesProgressive()
        for await (community, models) in progressiveStream {
            await MainActor.run {
                // Update community models with crossDissolve animation
                withAnimation(.easeInOut(duration: Constants.animationDuration)) {
                    communityModels[community] = models
                    communitiesLoadingStates[community] = false
                }
            }
        }

        await MainActor.run {
            isLoadingCommunity = false
        }
    }

    private func loadCommunityModels() async {
        isLoadingCommunity = true
        communityError = nil

        do {
            communityModels = try await viewModel.latestModelsFromDefaultCommunities()
        } catch {
            communityError = error
        }

        isLoadingCommunity = false
    }
}

// MARK: - Previews

#if DEBUG
    #Preview {
        DiscoveryCarouselView()
            .environment(\.discoveryCarousel, PreviewDiscoveryCarouselViewModel())
    }

    #Preview("With Filter Applied") {
        @Previewable @State var showingView: Bool = true

        if showingView {
            DiscoveryCarouselView()
                .environment(\.discoveryCarousel, PreviewDiscoveryCarouselViewModel())
                .task {
                    // Simulate user selecting a filter after a delay
                    try? await Task.sleep(
                        nanoseconds: DiscoveryConstants.PreviewData.loadingDelayNanoseconds
                    )
                    // This would be set by user interaction in real usage
                }
        }
    }
#endif
