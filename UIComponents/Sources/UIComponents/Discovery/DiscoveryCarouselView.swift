import Abstractions
import SwiftUI

// swiftlint:disable type_body_length
/// A discovery view for browsing and filtering AI models with progressive loading
internal struct DiscoveryCarouselView: View {
    // MARK: - Constants

    enum Constants {
        static let animationDuration: Double = 0.3
        static let pickerWidth: CGFloat = 300
        static let trendingLimit: Int = 12
        static let latestLimit: Int = 12
    }

    // MARK: - Environment

    @Environment(\.discoveryCarousel)
    var viewModel: DiscoveryCarouselViewModeling

    // MARK: - State

    @State private var recommendedModelsState: [DiscoveredModel] = []
    @State private var bestModelState: DiscoveredModel?
    @State private var trendingModelsState: [DiscoveredModel] = []
    @State private var latestModelsState: [DiscoveredModel] = []
    @State private var communityModelsState: [ModelCommunity: [DiscoveredModel]] = [:]
    @State private var communitiesLoadingStatesState: [ModelCommunity: Bool] = [:]
    @State private var isLoadingRecommendedState: Bool = true
    @State private var isLoadingBestState: Bool = true
    @State private var isLoadingTrendingState: Bool = true
    @State private var isLoadingLatestState: Bool = true
    @State private var isLoadingCommunityState: Bool = true
    @State private var recommendedErrorState: Error?
    @State private var bestErrorState: Error?
    @State private var trendingErrorState: Error?
    @State private var latestErrorState: Error?
    @State private var communityErrorState: Error?
    @State private var selectedFilterState: ModelTypeFilter = .text
    @State private var hasLoadedOnceState: Bool = false

    var recommendedModels: [DiscoveredModel] {
        get { recommendedModelsState }
        nonmutating set { recommendedModelsState = newValue }
    }

    var bestModel: DiscoveredModel? {
        get { bestModelState }
        nonmutating set { bestModelState = newValue }
    }

    var trendingModels: [DiscoveredModel] {
        get { trendingModelsState }
        nonmutating set { trendingModelsState = newValue }
    }

    var latestModels: [DiscoveredModel] {
        get { latestModelsState }
        nonmutating set { latestModelsState = newValue }
    }

    var communityModels: [ModelCommunity: [DiscoveredModel]] {
        get { communityModelsState }
        nonmutating set { communityModelsState = newValue }
    }

    var communitiesLoadingStates: [ModelCommunity: Bool] {
        get { communitiesLoadingStatesState }
        nonmutating set { communitiesLoadingStatesState = newValue }
    }

    var isLoadingRecommended: Bool {
        get { isLoadingRecommendedState }
        nonmutating set { isLoadingRecommendedState = newValue }
    }

    var isLoadingBest: Bool {
        get { isLoadingBestState }
        nonmutating set { isLoadingBestState = newValue }
    }

    var isLoadingTrending: Bool {
        get { isLoadingTrendingState }
        nonmutating set { isLoadingTrendingState = newValue }
    }

    var isLoadingLatest: Bool {
        get { isLoadingLatestState }
        nonmutating set { isLoadingLatestState = newValue }
    }

    var isLoadingCommunity: Bool {
        get { isLoadingCommunityState }
        nonmutating set { isLoadingCommunityState = newValue }
    }

    var recommendedError: Error? {
        get { recommendedErrorState }
        nonmutating set { recommendedErrorState = newValue }
    }

    var bestError: Error? {
        get { bestErrorState }
        nonmutating set { bestErrorState = newValue }
    }

    var trendingError: Error? {
        get { trendingErrorState }
        nonmutating set { trendingErrorState = newValue }
    }

    var latestError: Error? {
        get { latestErrorState }
        nonmutating set { latestErrorState = newValue }
    }

    var communityError: Error? {
        get { communityErrorState }
        nonmutating set { communityErrorState = newValue }
    }

    var selectedFilter: ModelTypeFilter {
        get { selectedFilterState }
        nonmutating set { selectedFilterState = newValue }
    }

    var hasLoadedOnce: Bool {
        get { hasLoadedOnceState }
        nonmutating set { hasLoadedOnceState = newValue }
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

    internal init() {
        // Initialize view with empty state
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
                Picker(selection: $selectedFilterState) {
                    ForEach(ModelTypeFilter.allCases) { filter in
                        Label {
                            Text(filter.displayName)
                        } icon: {
                            Image(systemName: filter.iconName)
                                .accessibilityHidden(true)
                        }
                            .tag(filter)
                    }
                } label: {
                    Text("Model Type", bundle: .module)
                }
                .pickerStyle(.segmented)
                .frame(width: Constants.pickerWidth)
                .help(String(localized: "Filter models by type", bundle: .module))
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
            ModelTypeFilterBar(selection: $selectedFilterState)
            #endif

            ScrollView(.vertical, showsIndicators: true) {
                VStack(alignment: .leading, spacing: DesignConstants.Spacing.huge) {
                    bestForDeviceSection

                    // Recommended models section - loads independently
                    recommendedSection

                    trendingSection
                    latestSection

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

    // MARK: - Progressive Data Loading

    private func loadModelsProgressive() async {
        // Load sections independently
        await withTaskGroup(of: Void.self) { group in
            group.addTask {
                await loadRecommendedModels()
            }
            group.addTask {
                await loadBestModel()
            }
            group.addTask {
                await loadTrendingModels()
            }
            group.addTask {
                await loadLatestModels()
            }
            group.addTask {
                await loadCommunityModelsProgressive()
            }
        }
    }

    func sectionErrorView(
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

    private func loadRecommendedModels() async {
        isLoadingRecommended = true
        recommendedError = nil
        recommendedModels = await viewModel.recommendedAllModels()

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
        communityModels = await viewModel.latestModelsFromDefaultCommunities()

        isLoadingCommunity = false
    }
}
// swiftlint:enable type_body_length

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
