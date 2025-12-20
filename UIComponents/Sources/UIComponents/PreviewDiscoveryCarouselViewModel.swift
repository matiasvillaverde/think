import Abstractions
import Foundation
import OSLog

/// Default view model implementation for discovery carousel functionality in previews
internal final actor PreviewDiscoveryCarouselViewModel: DiscoveryCarouselViewModeling {
    private enum Constants {
        static let maxPreviewResults: Int = 3
    }

    private let logger: Logger = .init(
        subsystem: Bundle.main.bundleIdentifier ?? "",
        category: "UI"
    )

    func recommendedLanguageModels() async throws -> [Abstractions.DiscoveredModel] {
        logger.warning("Default view model - recommendedLanguageModels called")
        let model: DiscoveredModel = await MainActor.run {
            let model: DiscoveredModel = DiscoveredModel(
                id: "mlx-community/Llama-3.2-3B-Instruct-4bit",
                name: "Llama-3.2-3B-Instruct-4bit",
                author: "mlx-community",
                downloads: DiscoveryConstants.PreviewData.previewDownloads1,
                likes: DiscoveryConstants.PreviewData.previewLikes1,
                tags: ["text-generation", "llama", "conversational"],
                lastModified: Date(),
                files: [],
                license: "llama3.2",
                licenseUrl: nil,
                metadata: [:]
            )
            model.enrich(with: EnrichedModelDetails(
                modelCard: nil, cardData: nil, imageUrls: [], detectedBackends: [.mlx]
            ))
            return model
        }
        return [model]
    }

    func recommendedAllModels() async throws -> [Abstractions.DiscoveredModel] {
        logger.warning("Default view model - recommendedAllModels called")
        let languageModel: DiscoveredModel = await createPreviewLanguageModel()
        let imageModel: DiscoveredModel = await createPreviewImageModel()
        return [languageModel, imageModel]
    }

    @MainActor
    private func createPreviewLanguageModel() -> DiscoveredModel {
        let model: DiscoveredModel = DiscoveredModel(
            id: "mlx-community/Llama-3.2-3B-Instruct-4bit",
            name: "Llama-3.2-3B-Instruct-4bit",
            author: "mlx-community",
            downloads: DiscoveryConstants.PreviewData.previewDownloads1,
            likes: DiscoveryConstants.PreviewData.previewLikes1,
            tags: ["text-generation", "llama", "conversational"],
            lastModified: Date(),
            files: [],
            license: "llama3.2",
            licenseUrl: nil,
            metadata: [:]
        )
        model.enrich(with: EnrichedModelDetails(
            modelCard: nil, cardData: nil, imageUrls: [], detectedBackends: [.mlx]
        ))
        return model
    }

    @MainActor
    private func createPreviewImageModel() -> DiscoveredModel {
        let model: DiscoveredModel = DiscoveredModel(
            id: "coreml-community/coreml-dreamshaper-4-and-5",
            name: "dreamshaper-4-and-5",
            author: "coreml-community",
            downloads: DiscoveryConstants.PreviewData.previewDownloads2,
            likes: DiscoveryConstants.PreviewData.previewLikes2,
            tags: ["stable-diffusion", "coreml", "text-to-image"],
            lastModified: Date(),
            files: [],
            license: "creativeml-openrail-m",
            licenseUrl: nil,
            metadata: [:]
        )
        model.enrich(with: EnrichedModelDetails(
            modelCard: nil, cardData: nil, imageUrls: [], detectedBackends: [.coreml]
        ))
        return model
    }

    @MainActor
    func latestModelsFromDefaultCommunities() throws -> [ModelCommunity: [DiscoveredModel]] {
        logger.warning("Default view model - latestModelsFromDefaultCommunities called")
        let mlxCommunity: ModelCommunity = ModelCommunity.defaultCommunities[0]
        let model: DiscoveredModel = DiscoveredModel(
            id: "mlx-community/Mistral-7B-Instruct-v0.3-4bit",
            name: "Mistral-7B-Instruct-v0.3-4bit",
            author: "mlx-community",
            downloads: DiscoveryConstants.PreviewData.previewDownloads2,
            likes: DiscoveryConstants.PreviewData.previewLikes2,
            tags: ["text-generation", "mistral"],
            lastModified: Date(),
            files: [],
            license: "apache-2.0",
            licenseUrl: nil,
            metadata: [:]
        )
        model.enrich(with: EnrichedModelDetails(
            modelCard: nil, cardData: nil, imageUrls: [], detectedBackends: [.mlx]
        ))
        return [mlxCommunity: [model]]
    }

    func getDefaultCommunitiesFromProtocol() -> [ModelCommunity] {
        logger.warning("Default view model - getDefaultCommunitiesFromProtocol called")
        return ModelCommunity.defaultCommunities
    }

    func latestModelsFromDefaultCommunitiesProgressive() -> AsyncStream<(
        ModelCommunity,
        [DiscoveredModel]
    )> {
        logger.warning("Default view model - latestModelsFromDefaultCommunitiesProgressive called")
        return AsyncStream { continuation in
            Task {
                await processCommunitiesProgressively(continuation: continuation)
            }
        }
    }

    private func processCommunitiesProgressively(
        continuation: AsyncStream<(ModelCommunity, [DiscoveredModel])>.Continuation
    ) async {
        for (index, community) in ModelCommunity.defaultCommunities.enumerated() {
            if index > 0 {
                try? await Task.sleep(
                    nanoseconds: DiscoveryConstants.PreviewData.loadingDelayNanoseconds
                )
            }
            let model: DiscoveredModel = await createPreviewModel(
                community: community,
                index: index
            )
            continuation.yield((community, [model]))
        }
        continuation.finish()
    }

    @MainActor
    private func createPreviewModel(community: ModelCommunity, index: Int) -> DiscoveredModel {
        let model: DiscoveredModel = DiscoveredModel(
            id: "\(community.id)/preview-model-\(index)",
            name: "Preview Model \(index + 1)",
            author: community.id,
            downloads: DiscoveryConstants.PreviewData.previewDownloads1 * (index + 1),
            likes: DiscoveryConstants.PreviewData.previewLikes1 * (index + 1),
            tags: ["preview", "test"],
            lastModified: Date(),
            files: [],
            license: "mit",
            licenseUrl: nil,
            metadata: [:]
        )
        model.enrich(with: EnrichedModelDetails(
            modelCard: nil,
            cardData: nil,
            imageUrls: [],
            detectedBackends: community.supportedBackends
        ))
        return model
    }

    // MARK: - Search Methods

    // swiftlint:disable:next function_parameter_count
    func searchModels(
        query _: String?,
        author _: String?,
        tags _: [String],
        sort _: SortOption,
        direction _: SortDirection,
        limit: Int
    ) async throws -> [DiscoveredModel] {
        logger.warning("Preview view model - searchModels called")
        // Return preview search results
        return await createPreviewSearchResults(count: min(limit, Constants.maxPreviewResults))
    }

    // swiftlint:disable:next function_parameter_count
    func searchModelsPaginated(
        query _: String?,
        author _: String?,
        tags _: [String],
        cursor: String?,
        sort _: SortOption,
        direction _: SortDirection,
        limit: Int
    ) async throws -> ModelPage {
        logger.warning("Preview view model - searchModelsPaginated called")
        let models: [DiscoveredModel] = await createPreviewSearchResults(
            count: min(limit, Constants.maxPreviewResults)
        )
        // Return page with optional next cursor for pagination preview
        return ModelPage(
            models: models,
            hasNextPage: cursor == nil,
            nextPageToken: cursor == nil ? "next-page-cursor" : nil
        )
    }

    func searchAndEnrichModels(
        query _: String?,
        limit: Int
    ) async throws -> [DiscoveredModel] {
        logger.warning("Preview view model - searchAndEnrichModels called")
        return await createPreviewSearchResults(count: min(limit, Constants.maxPreviewResults))
    }

    @MainActor
    private func createPreviewSearchResults(count: Int) -> [DiscoveredModel] {
        let baseDownloads: Int = 10_000
        let baseLikes: Int = 100
        let secondsPerDay: Int = 86_400

        return (0..<count).map { index -> DiscoveredModel in
            let model: DiscoveredModel = DiscoveredModel(
                id: "search-result-\(index)",
                name: "Search Result Model \(index + 1)",
                author: "huggingface-author",
                downloads: baseDownloads * (count - index),
                likes: baseLikes * (count - index),
                tags: ["search", "preview", "model"],
                lastModified: Date().addingTimeInterval(-Double(index * secondsPerDay)),
                files: [],
                license: "apache-2.0",
                licenseUrl: nil,
                metadata: [:]
            )
            model.enrich(with: EnrichedModelDetails(
                modelCard: "This is a preview search result model for testing.",
                cardData: nil,
                imageUrls: [],
                detectedBackends: [.mlx, .gguf]
            ))
            return model
        }
    }
}
