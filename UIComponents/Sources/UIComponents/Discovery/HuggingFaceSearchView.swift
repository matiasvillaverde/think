import Abstractions
import SwiftUI

/// A view for searching and browsing HuggingFace models
internal struct HuggingFaceSearchView: View {
    // MARK: - Constants

    private enum Constants {
        static let searchDebounceDelay: Double = 0.5
        static let resultsPerPage: Int = 20
        static let gridMinimumWidth: CGFloat = 300
        static let gridMaximumWidth: CGFloat = 400
        static let gridColumns: [GridItem] = [
            GridItem(.adaptive(minimum: gridMinimumWidth, maximum: gridMaximumWidth))
        ]
    }

    // MARK: - Environment

    @Environment(\.discoveryCarousel)
    private var viewModel: DiscoveryCarouselViewModeling

    @Environment(\.dismiss)
    private var dismiss: DismissAction

    // MARK: - State

    @State private var searchQuery: String = ""
    @State private var searchResults: [DiscoveredModel] = []
    @State private var isSearching: Bool = false
    @State private var searchError: Error?
    @State private var selectedSort: SortOption = .downloads
    @State private var selectedDirection: SortDirection = .descending
    @State private var searchTask: Task<Void, Never>?
    @State private var currentCursor: String?
    @State private var hasMoreResults: Bool = false
    @State private var isLoadingMore: Bool = false

    // MARK: - Body

    internal var body: some View {
        NavigationStack {
            contentView
                .navigationTitle("Search HuggingFace")
                #if !os(macOS)
                .navigationBarTitleDisplayMode(.inline)
                #endif
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") {
                            dismiss()
                        }
                    }
                }
                .navigationDestination(for: DiscoveredModel.self) { model in
                    DiscoveryModelDetailView(model: model)
                }
        }
    }

    private var contentView: some View {
        VStack(spacing: 0) {
            searchHeader
                .padding()

            Divider()

            mainContent
        }
    }

    @ViewBuilder private var mainContent: some View {
        if isSearching,
            searchResults.isEmpty {
            HuggingFaceSearchLoadingView()
        } else if let error = searchError {
            HuggingFaceSearchErrorView(error: error, onRetry: performSearch)
        } else if searchResults.isEmpty,
            !searchQuery.isEmpty {
            HuggingFaceSearchEmptyView()
        } else if !searchResults.isEmpty {
            resultsView
        } else {
            HuggingFaceSearchPlaceholderView()
        }
    }

    // MARK: - Subviews

    private var searchHeader: some View {
        HuggingFaceSearchHeader(
            searchQuery: $searchQuery,
            selectedSort: $selectedSort,
            selectedDirection: $selectedDirection,
            onSearch: performSearch,
            onClear: clearSearch
        )
        .onChange(of: searchQuery) { _, newValue in
            debounceSearch(newValue)
        }
    }

    private var resultsView: some View {
        ScrollView {
            LazyVGrid(
                columns: Constants.gridColumns,
                spacing: DesignConstants.Spacing.large
            ) {
                ForEach(searchResults, id: \.id) { model in
                    NavigationLink(value: model) {
                        DiscoveryModelCard(model: model)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding()

            if hasMoreResults {
                loadMoreButton
                    .padding(.bottom, DesignConstants.Spacing.large)
            }
        }
    }

    private var loadMoreButton: some View {
        Button {
            Task {
                await loadMoreResults()
            }
        } label: {
            if isLoadingMore {
                ProgressView()
                    .progressViewStyle(.circular)
            } else {
                Label("Load More", systemImage: "arrow.down.circle")
                    .font(.subheadline)
            }
        }
        .buttonStyle(.bordered)
        .disabled(isLoadingMore)
    }

    // MARK: - Helper Methods

    private func clearSearch() {
        searchQuery = ""
        searchResults = []
        searchError = nil
    }

    private func debounceSearch(_ query: String) {
        // Cancel previous search task
        searchTask?.cancel()

        // Don't search for empty queries
        guard !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            searchResults = []
            searchError = nil
            return
        }

        // Create new search task with debounce
        searchTask = Task {
            // Debounce delay
            do {
                try await Task.sleep(for: .seconds(Constants.searchDebounceDelay))
            } catch {
                return // Task was cancelled
            }

            // Check if task was cancelled during sleep
            if Task.isCancelled {
                return
            }

            await MainActor.run {
                performSearch()
            }
        }
    }

    private func performSearch() {
        let query: String = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else {
            return
        }

        Task {
            await executeSearch(query: query)
        }
    }

    private func executeSearch(query: String) async {
        await MainActor.run {
            isSearching = true
            searchError = nil
            searchResults = []
            currentCursor = nil
            hasMoreResults = false
        }

        do {
            let page: ModelPage = try await viewModel.searchModelsPaginated(
                query: query,
                author: nil,
                tags: [],
                cursor: nil,
                sort: selectedSort,
                direction: selectedDirection,
                limit: Constants.resultsPerPage
            )

            await MainActor.run {
                searchResults = page.models
                currentCursor = page.nextPageToken
                hasMoreResults = page.hasNextPage
                isSearching = false
            }

            if page.models.isEmpty, query.contains("/") {
                await attemptDirectLookup(for: query)
            }
        } catch {
            await MainActor.run {
                searchError = error
                isSearching = false
            }
        }
    }

    private func attemptDirectLookup(for modelId: String) async {
        do {
            let directModel: DiscoveredModel = try await viewModel.discoverModelById(modelId)
            await MainActor.run {
                searchResults = [directModel]
                currentCursor = nil
                hasMoreResults = false
            }
        } catch {
            await MainActor.run {
                searchError = error
            }
        }
    }

    private func loadMoreResults() async {
        guard let cursor: String = currentCursor,
            !isLoadingMore else {
            return
        }

        await MainActor.run {
            isLoadingMore = true
        }

        do {
            let page: ModelPage = try await viewModel.searchModelsPaginated(
                query: searchQuery,
                author: nil,
                tags: [],
                cursor: cursor,
                sort: selectedSort,
                direction: selectedDirection,
                limit: Constants.resultsPerPage
            )

            await MainActor.run {
                searchResults.append(contentsOf: page.models)
                currentCursor = page.nextPageToken
                hasMoreResults = page.hasNextPage
                isLoadingMore = false
            }
        } catch {
            await MainActor.run {
                searchError = error
                isLoadingMore = false
            }
        }
    }
}

// MARK: - SortOption Display Names

extension SortOption {
    var displayName: String {
        switch self {
        case .downloads:
            return String(localized: "Downloads", bundle: .module)

        case .likes:
            return String(localized: "Likes", bundle: .module)

        case .lastModified:
            return String(localized: "Recent", bundle: .module)

        case .trending:
            return String(localized: "Trending", bundle: .module)
        }
    }
}

// MARK: - Preview

#if DEBUG
    #Preview {
        HuggingFaceSearchView()
            .environment(\.discoveryCarousel, PreviewDiscoveryCarouselViewModel())
    }
#endif
