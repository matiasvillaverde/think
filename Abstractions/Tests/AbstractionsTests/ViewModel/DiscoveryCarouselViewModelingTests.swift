import Testing
@testable import Abstractions
import Foundation

@Suite("DiscoveryCarouselViewModeling Protocol Tests")
struct DiscoveryCarouselViewModelingTests {
    @Test("Protocol conforms to Actor")
    func protocolConformance() {
        // Verify the protocol exists and conforms to Actor
        // by creating a minimal conforming type
        actor TestViewModel: DiscoveryCarouselViewModeling {
            func recommendedLanguageModels() async -> [DiscoveredModel] {
                await Task.yield()
                return []
            }

            func recommendedAllModels() async -> [DiscoveredModel] {
                await Task.yield()
                return []
            }

            func latestModelsFromDefaultCommunities() async -> [ModelCommunity: [DiscoveredModel]] {
                await Task.yield()
                return [:]
            }
            func getDefaultCommunitiesFromProtocol() -> [ModelCommunity] { [] }
            func latestModelsFromDefaultCommunitiesProgressive() -> AsyncStream<(ModelCommunity, [DiscoveredModel])> {
                AsyncStream { _ in
                    // Empty stream for test
                }
            }
            func searchModels(
                query: String?,
                author: String?,
                tags: [String],
                sort: SortOption,
                direction: SortDirection,
                limit: Int
            ) async throws -> [DiscoveredModel] {
                try await Task.sleep(nanoseconds: 0)
                return []
            }

            func searchModelsPaginated(
                query: String?,
                author: String?,
                tags: [String],
                cursor: String?,
                sort: SortOption,
                direction: SortDirection,
                limit: Int
            ) async throws -> ModelPage {
                try await Task.sleep(nanoseconds: 0)
                return .empty
            }

            func searchAndEnrichModels(
                query: String?,
                limit: Int
            ) async throws -> [DiscoveredModel] {
                try await Task.sleep(nanoseconds: 0)
                return []
            }

            func discoverModelById(_ modelId: String) async throws -> DiscoveredModel {
                try await Task.sleep(nanoseconds: 0)
                return await MainActor.run {
                    DiscoveredModel(
                        id: modelId,
                        name: modelId,
                        author: "test",
                        downloads: 0,
                        likes: 0,
                        tags: [],
                        lastModified: Date()
                    )
                }
            }

            func trendingModels(limit: Int) async throws -> [DiscoveredModel] {
                try await Task.sleep(nanoseconds: 0)
                return []
            }

            func latestModels(limit: Int) async throws -> [DiscoveredModel] {
                try await Task.sleep(nanoseconds: 0)
                return []
            }

            func bestModelForDevice() async -> DiscoveredModel? {
                await Task.yield()
                return nil
            }
        }

        // If this compiles, the protocol exists and conforms to Actor
        let viewModel = TestViewModel()
        // The fact that this compiles confirms protocol conformance and Actor inheritance
        _ = viewModel
    }

    @Test("Protocol has required method signatures")
    func protocolMethods() async throws {
        // Create a test implementation to verify method signatures
        actor TestViewModel: DiscoveryCarouselViewModeling {
            var recommendedLanguageModelsCalled = false
            var recommendedAllModelsCalled = false
            var latestModelsCalled = false
            var getDefaultCommunitiesCalled = false
            var progressiveStreamCalled = false
            var searchModelsCalled = false
            var searchModelsPaginatedCalled = false
            var searchAndEnrichModelsCalled = false

            func recommendedLanguageModels() async -> [DiscoveredModel] {
                await Task.yield()
                recommendedLanguageModelsCalled = true
                return []
            }

            func recommendedAllModels() async -> [DiscoveredModel] {
                await Task.yield()
                recommendedAllModelsCalled = true
                return []
            }

            func latestModelsFromDefaultCommunities() async -> [ModelCommunity: [DiscoveredModel]] {
                await Task.yield()
                latestModelsCalled = true
                return [:]
            }

            func getDefaultCommunitiesFromProtocol() -> [ModelCommunity] {
                getDefaultCommunitiesCalled = true
                return []
            }

            func latestModelsFromDefaultCommunitiesProgressive() -> AsyncStream<(ModelCommunity, [DiscoveredModel])> {
                progressiveStreamCalled = true
                return AsyncStream { _ in
                    // Empty stream for test
                }
            }

            func searchModels(
                query: String?,
                author: String?,
                tags: [String],
                sort: SortOption,
                direction: SortDirection,
                limit: Int
            ) async throws -> [DiscoveredModel] {
                try await Task.sleep(nanoseconds: 0)
                searchModelsCalled = true
                return []
            }

            func searchModelsPaginated(
                query: String?,
                author: String?,
                tags: [String],
                cursor: String?,
                sort: SortOption,
                direction: SortDirection,
                limit: Int
            ) async throws -> ModelPage {
                try await Task.sleep(nanoseconds: 0)
                searchModelsPaginatedCalled = true
                return .empty
            }

            func searchAndEnrichModels(
                query: String?,
                limit: Int
            ) async throws -> [DiscoveredModel] {
                try await Task.sleep(nanoseconds: 0)
                searchAndEnrichModelsCalled = true
                return []
            }

            func discoverModelById(_ modelId: String) async throws -> DiscoveredModel {
                try await Task.sleep(nanoseconds: 0)
                return await MainActor.run {
                    DiscoveredModel(
                        id: modelId,
                        name: modelId,
                        author: "test",
                        downloads: 0,
                        likes: 0,
                        tags: [],
                        lastModified: Date()
                    )
                }
            }

            func trendingModels(limit: Int) async throws -> [DiscoveredModel] {
                try await Task.sleep(nanoseconds: 0)
                return []
            }

            func latestModels(limit: Int) async throws -> [DiscoveredModel] {
                try await Task.sleep(nanoseconds: 0)
                return []
            }

            func bestModelForDevice() async -> DiscoveredModel? {
                await Task.yield()
                return nil
            }
        }

        let viewModel = TestViewModel()

        // Test recommendedLanguageModels method
        let languageModels = await viewModel.recommendedLanguageModels()
        #expect(languageModels.isEmpty)
        #expect(await viewModel.recommendedLanguageModelsCalled)

        // Test recommendedAllModels method
        let allModels = await viewModel.recommendedAllModels()
        #expect(allModels.isEmpty)
        #expect(await viewModel.recommendedAllModelsCalled)

        // Test latestModelsFromDefaultCommunities method
        let communities = await viewModel.latestModelsFromDefaultCommunities()
        #expect(communities.isEmpty)
        #expect(await viewModel.latestModelsCalled)

        // Test getDefaultCommunitiesFromProtocol method
        let defaultCommunities = await viewModel.getDefaultCommunitiesFromProtocol()
        #expect(defaultCommunities.isEmpty)
        #expect(await viewModel.getDefaultCommunitiesCalled)

        // Test latestModelsFromDefaultCommunitiesProgressive method
        _ = await viewModel.latestModelsFromDefaultCommunitiesProgressive()
        #expect(await viewModel.progressiveStreamCalled)
        // Note: Not testing stream content as it's empty for this test implementation

        // Test search methods
        let searchResults = try await viewModel.searchModels(
            query: nil,
            author: nil,
            tags: [],
            sort: .downloads,
            direction: .descending,
            limit: 10
        )
        #expect(searchResults.isEmpty)
        #expect(await viewModel.searchModelsCalled)

        let pagedResults = try await viewModel.searchModelsPaginated(
            query: nil,
            author: nil,
            tags: [],
            cursor: nil,
            sort: .downloads,
            direction: .descending,
            limit: 10
        )
        #expect(pagedResults.isEmpty)
        #expect(await viewModel.searchModelsPaginatedCalled)

        let enrichedResults = try await viewModel.searchAndEnrichModels(query: nil, limit: 10)
        #expect(enrichedResults.isEmpty)
        #expect(await viewModel.searchAndEnrichModelsCalled)

        let discovered = try await viewModel.discoverModelById("test/model")
        let discoveredId = await MainActor.run { discovered.id }
        #expect(discoveredId == "test/model")

        let trending = try await viewModel.trendingModels(limit: 5)
        #expect(trending.isEmpty)

        let latest = try await viewModel.latestModels(limit: 5)
        #expect(latest.isEmpty)

        let best = await viewModel.bestModelForDevice()
        #expect(best == nil)
    }
}
