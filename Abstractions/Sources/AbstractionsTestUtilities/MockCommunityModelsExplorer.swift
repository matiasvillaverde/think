import Foundation
import Abstractions

/// Mock implementation of CommunityModelsExplorerProtocol for testing
public final class MockCommunityModelsExplorer: CommunityModelsExplorerProtocol, @unchecked Sendable {
    public var discoverModelResponses: [String: DiscoveredModel] = [:]
    public var exploreCommunityResponses: [String: ModelPage] = [:]
    public var discoverModelCallCount = 0
    public var shouldThrowError: Set<String> = []
    public var prepareForDownloadResult: SendableModel?
    public var searchPaginatedResponses: [SortOption: ModelPage] = [:]

    // New properties for progressive loading tests
    public var mockDefaultCommunities: [ModelCommunity] = ModelCommunity.defaultCommunities
    public var mockCommunityModels: [ModelCommunity: [DiscoveredModel]] = [:]
    public var shouldFailForCommunity: [String: Bool] = [:]
    public var simulateNetworkDelay = false

    public init() {
        // Empty initializer for mock
    }

    public func discoverModel(_ modelId: String) async throws -> DiscoveredModel {
        discoverModelCallCount += 1
        try await Task.sleep(nanoseconds: 0)

        if shouldThrowError.contains(modelId) {
            throw ModelDownloadError.repositoryNotFound(modelId)
        }

        guard let model = discoverModelResponses[modelId] else {
            throw ModelDownloadError.repositoryNotFound(modelId)
        }
        return model
    }

    public func exploreCommunity(
        _ community: ModelCommunity,
        query: String? = nil,
        sort: SortOption = .downloads,
        direction: SortDirection = .descending,
        limit: Int = 50
    ) async throws -> [DiscoveredModel] {
        // Simulate network delay if requested
        if simulateNetworkDelay {
            try await Task.sleep(nanoseconds: 100_000_000) // 0.1 second
        }

        // Check if this community should fail
        if shouldFailForCommunity[community.id] == true {
            throw ModelDownloadError.repositoryNotFound(community.id)
        }

        // Return models from mockCommunityModels if available
        if let models = mockCommunityModels[community] {
            return models
        }

        // Fallback to old behavior
        guard let page = exploreCommunityResponses[community.id] else {
            return []
        }
        return page.models
    }

    public func searchPaginated(
        query: String?,
        author: String?,
        tags: [String],
        cursor: String?,
        sort: SortOption = .downloads,
        direction: SortDirection = .descending,
        limit: Int = 50
    ) async throws -> ModelPage {
        try await Task.sleep(nanoseconds: 0)
        if let response = searchPaginatedResponses[sort] {
            return response
        }
        return ModelPage(models: [], hasNextPage: false, nextPageToken: nil, totalCount: 0)
    }

    public func searchByTags(
        _ tags: [String],
        community: ModelCommunity?,
        sort: SortOption = .downloads,
        limit: Int = 50
    ) async throws -> [DiscoveredModel] {
        try await Task.sleep(nanoseconds: 0)
        return []
    }

    public func getDefaultCommunities() -> [ModelCommunity] {
        mockDefaultCommunities
    }

    @preconcurrency
    @MainActor
    public func prepareForDownload(
        _ model: DiscoveredModel,
        preferredBackend: SendableModel.Backend?
    ) async throws -> SendableModel {
        try await Task.sleep(nanoseconds: 0)
        guard let result = prepareForDownloadResult else {
            throw ModelDownloadError.repositoryNotFound(model.id)
        }
        return result
    }

    public func getModelPreview(_ model: DiscoveredModel) async -> ModelInfo {
        // Return a basic ModelInfo for testing
        // Cache values to avoid actor isolation issues
        let modelId = await model.id
        let modelName = await model.name
        let backends = await model.detectedBackends

        return ModelInfo(
            id: UUID(),
            name: modelName,
            backend: backends.first ?? .mlx,
            location: URL(string: "https://huggingface.co/\(modelId)") ?? URL(fileURLWithPath: "/tmp/\(modelId)"),
            totalSize: 1_000_000,
            downloadDate: Date()
        )
    }

    @preconcurrency
    @MainActor
    public func populateImages(for model: DiscoveredModel) async throws -> DiscoveredModel {
        try await Task.sleep(nanoseconds: 0)
        // Mock implementation that simulates image population

        // Check if this model should throw an error
        if shouldThrowError.contains(model.id) {
            throw ImageExtractionError.networkError("Mock network error")
        }

        // Simulate different scenarios based on model ID and enrich in-place
        let imageUrls: [String]
        if model.id.contains("with-images") {
            imageUrls = [
                "https://huggingface.co/\(model.id)/resolve/main/architecture.png",
                "https://huggingface.co/\(model.id)/resolve/main/sample.jpg"
            ]
        } else if model.id.contains("converted") {
            // Simulate fallback to original model
            imageUrls = [
                "https://huggingface.co/original/model/resolve/main/diagram.png"
            ]
        } else if model.id.contains("no-images") {
            imageUrls = []
        } else {
            // Default case: return one sample image
            imageUrls = [
                "https://huggingface.co/\(model.id)/resolve/main/example.png"
            ]
        }

        // Enrich the model with the new image URLs
        let enrichedDetails = EnrichedModelDetails(
            modelCard: model.modelCard,
            cardData: model.cardData,
            imageUrls: imageUrls,
            detectedBackends: model.detectedBackends
        )
        model.enrich(with: enrichedDetails)

        return model
    }

    @preconcurrency
    @MainActor
    public func enrichModel(_ model: DiscoveredModel) async throws -> DiscoveredModel {
        try await Task.sleep(nanoseconds: 0)
        // Mock implementation that simulates model enrichment

        // Check if this model should throw an error
        if shouldThrowError.contains(model.id) {
            throw ModelDownloadError.repositoryNotFound(model.id)
        }

        // Create enriched data
        let modelCard = model.modelCard ?? "Mock model card for \(model.id)"

        let cardData = model.cardData ?? ModelCardData(
            license: "mit",
            licenseName: "MIT License",
            licenseLink: "https://opensource.org/licenses/MIT",
            baseModel: [],
            baseModelRelation: nil,
            thumbnail: "https://huggingface.co/\(model.id)/resolve/main/thumbnail.jpg",
            pipelineTag: "text-generation",
            libraryName: "transformers",
            language: ["en"],
            datasets: ["common_crawl"],
            tags: model.tags,
            extraGatedPrompt: nil,
            widget: []
        )

        let imageUrls = model.imageUrls.isEmpty ? [
            "https://huggingface.co/\(model.id)/resolve/main/architecture.png"
        ] : model.imageUrls

        // Enrich the model in-place
        let enrichedDetails = EnrichedModelDetails(
            modelCard: modelCard,
            cardData: cardData,
            imageUrls: imageUrls,
            detectedBackends: model.detectedBackends
        )
        model.enrich(with: enrichedDetails)

        return model
    }

    public func enrichModels(_ models: [DiscoveredModel]) async -> [DiscoveredModel] {
        await Task.yield()
        var enrichedModels: [DiscoveredModel] = []

        for model in models {
            do {
                let enriched = try await enrichModel(model)
                enrichedModels.append(enriched)
            } catch {
                // Return original model on failure
                enrichedModels.append(model)
            }
        }

        return enrichedModels
    }
}
