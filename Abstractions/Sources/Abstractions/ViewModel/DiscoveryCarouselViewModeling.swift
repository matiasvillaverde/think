import Foundation

/// Protocol for discovering and recommending AI models based on device compatibility
public protocol DiscoveryCarouselViewModeling: Actor {
    /// Returns language models compatible with the current device for full GPU offload
    /// - Returns: Array of discovered language models that can run smoothly on the device
    /// - Throws: Error if discovery fails
    func recommendedLanguageModels() async throws -> [DiscoveredModel]

    /// Returns all models (language + image) compatible with the current device
    /// - Returns: Array of all discovered models that can run smoothly on the device
    /// - Throws: Error if discovery fails
    func recommendedAllModels() async throws -> [DiscoveredModel]

    /// Returns latest models from all default communities, grouped by community
    /// - Returns: Dictionary mapping communities to their latest models
    /// - Throws: Error if fetching community models fails
    func latestModelsFromDefaultCommunities() async throws -> [ModelCommunity: [DiscoveredModel]]

    /// Returns default communities from the protocol method instead of static property
    /// - Returns: Array of default communities for progressive loading
    func getDefaultCommunitiesFromProtocol() -> [ModelCommunity]

    /// Returns progressive stream of community models for progressive loading UX
    /// - Returns: AsyncStream yielding community and models as they load
    func latestModelsFromDefaultCommunitiesProgressive() -> AsyncStream<(ModelCommunity, [DiscoveredModel])>

    // MARK: - HuggingFace Search

    /// Search for models on HuggingFace Hub
    /// - Parameters:
    ///   - query: Search query text
    ///   - author: Optional author filter
    ///   - tags: Optional tags filter
    ///   - sort: Sort option (downloads, likes, lastModified)
    ///   - direction: Sort direction
    ///   - limit: Maximum results to return
    /// - Returns: Array of discovered models matching the search
    /// - Throws: Error if search fails
    func searchModels(
        query: String?,
        author: String?,
        tags: [String],
        sort: SortOption,
        direction: SortDirection,
        limit: Int
    ) async throws -> [DiscoveredModel]

    /// Search for models with pagination support
    /// - Parameters:
    ///   - query: Search query text
    ///   - author: Optional author filter
    ///   - tags: Optional tags filter
    ///   - cursor: Pagination cursor from previous page
    ///   - sort: Sort option
    ///   - direction: Sort direction
    ///   - limit: Results per page
    /// - Returns: Page of models with optional cursor for next page
    /// - Throws: Error if search fails
    func searchModelsPaginated(
        query: String?,
        author: String?,
        tags: [String],
        cursor: String?,
        sort: SortOption,
        direction: SortDirection,
        limit: Int
    ) async throws -> ModelPage

    /// Search and enrich models with full metadata
    /// - Parameters:
    ///   - query: Search query text
    ///   - limit: Maximum results to return
    /// - Returns: Array of enriched discovered models
    /// - Throws: Error if search or enrichment fails
    func searchAndEnrichModels(
        query: String?,
        limit: Int
    ) async throws -> [DiscoveredModel]
}
