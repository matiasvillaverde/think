import Foundation

/// Protocol for discovering and recommending AI models based on device compatibility
public protocol DiscoveryCarouselViewModeling: Actor {
    /// Returns language models compatible with the current device for full GPU offload
    /// - Returns: Array of discovered language models that can run smoothly on the device
    func recommendedLanguageModels() async -> [DiscoveredModel]

    /// Returns all models (language + image) compatible with the current device
    /// - Returns: Array of all discovered models that can run smoothly on the device
    func recommendedAllModels() async -> [DiscoveredModel]

    /// Returns latest models from all default communities, grouped by community
    /// - Returns: Dictionary mapping communities to their latest models
    func latestModelsFromDefaultCommunities() async -> [ModelCommunity: [DiscoveredModel]]

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

    // MARK: - Direct Model Discovery

    /// Discover a model directly by its HuggingFace ID
    /// - Parameter modelId: Model identifier (e.g., "owner/model-name")
    /// - Returns: Discovered model with full metadata
    func discoverModelById(_ modelId: String) async throws -> DiscoveredModel

    // MARK: - Trending and Best For Device

    /// Fetch trending models from HuggingFace, filtered to supported backends
    /// - Parameter limit: Maximum results to return
    /// - Returns: Array of trending models compatible with MLX or GGUF
    func trendingModels(limit: Int) async throws -> [DiscoveredModel]

    /// Fetch latest models from HuggingFace, filtered to supported backends
    /// - Parameter limit: Maximum results to return
    /// - Returns: Array of recently updated models compatible with MLX or GGUF
    func latestModels(limit: Int) async throws -> [DiscoveredModel]

    /// Determine the single best model for the current device
    /// - Returns: Best compatible model, or nil if none found
    func bestModelForDevice() async -> DiscoveredModel?
}
