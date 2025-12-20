import Abstractions
import Foundation
import OSLog

// MARK: - HuggingFace Search Extension

extension DiscoveryCarouselViewModel {
    /// Search for models on HuggingFace Hub
    public func searchModels(
        query: String?,
        author: String? = nil,
        tags: [String] = [],
        sort: SortOption = .downloads,
        direction: SortDirection = .descending,
        limit: Int = 50
    ) async throws -> [DiscoveredModel] {
        logger.info("""
            Searching HuggingFace models - \
            query: \(query ?? "none"), \
            author: \(author ?? "none"), \
            tags: \(tags.joined(separator: ",")), \
            sort: \(sort.rawValue), \
            limit: \(limit)
            """)

        let page: ModelPage = try await communityExplorer.searchPaginated(
            query: query,
            author: author,
            tags: tags,
            cursor: nil,
            sort: sort,
            direction: direction,
            limit: limit
        )

        let models: [DiscoveredModel] = page.models

        logger.info("Search completed with \(models.count) results")
        return models
    }

    /// Search for models with pagination support
    public func searchModelsPaginated(
        query: String?,
        author: String? = nil,
        tags: [String] = [],
        cursor: String? = nil,
        sort: SortOption = .downloads,
        direction: SortDirection = .descending,
        limit: Int = 50
    ) async throws -> ModelPage {
        logger.info("""
            Searching HuggingFace models with pagination - \
            query: \(query ?? "none"), \
            cursor: \(cursor ?? "none"), \
            limit: \(limit)
            """)

        let page: ModelPage = try await communityExplorer.searchPaginated(
            query: query,
            author: author,
            tags: tags,
            cursor: cursor,
            sort: sort,
            direction: direction,
            limit: limit
        )

        logger.info("Paginated search completed with \(page.models.count) results")
        return page
    }

    /// Search and enrich models with full metadata
    public func searchAndEnrichModels(
        query: String?,
        limit: Int = 50
    ) async throws -> [DiscoveredModel] {
        logger.info("""
            Searching and enriching models - \
            query: \(query ?? "none"), \
            limit: \(limit)
            """)

        // First, perform the basic search
        let basicModels: [DiscoveredModel] = try await searchModels(
            query: query,
            limit: limit
        )

        // Then enrich the models with full metadata
        let enrichedModels: [DiscoveredModel] = await communityExplorer.enrichModels(basicModels)

        logger.info("Search and enrichment completed with \(enrichedModels.count) models")
        return enrichedModels
    }
}
