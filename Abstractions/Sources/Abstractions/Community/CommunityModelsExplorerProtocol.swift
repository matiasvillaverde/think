import Foundation

/// Protocol for exploring and discovering AI models from HuggingFace communities
///
/// This protocol defines the interface for discovering, exploring, and preparing
/// AI models from various HuggingFace communities. Implementations should provide
/// thread-safe model discovery operations with proper error handling.
///
/// The protocol supports:
/// - Community-based model exploration
/// - Model search with filtering and sorting
/// - Backend detection for discovered models
/// - Conversion to downloadable format
///
/// ## Example Usage
/// ```swift
/// let explorer: CommunityModelsExplorerProtocol = // ... injected dependency
/// 
/// // Explore MLX community models
/// let models = try await explorer.exploreCommunity(.mlxCommunity, query: "llama")
/// 
/// // Get specific model details
/// let model = try await explorer.discoverModel("mlx-community/Llama-3.2-1B-4bit")
/// 
/// // Prepare for download
/// let sendableModel = try await explorer.prepareForDownload(model)
/// ```
public protocol CommunityModelsExplorerProtocol: Sendable {
    // MARK: - Community Exploration

    /// Get the default model communities
    /// - Returns: Array of default communities (mlx, lmstudio, coreml)
    func getDefaultCommunities() -> [ModelCommunity]

    /// Explore models from a specific community
    /// - Parameters:
    ///   - community: The community to explore
    ///   - query: Optional search query
    ///   - sort: Sort option (default: downloads)
    ///   - direction: Sort direction (default: descending)
    ///   - limit: Maximum results (default: 50)
    /// - Returns: Array of discovered models with detected backends
    func exploreCommunity(
        _ community: ModelCommunity,
        query: String?,
        sort: SortOption,
        direction: SortDirection,
        limit: Int
    ) async throws -> [DiscoveredModel]

    // MARK: - Model Discovery

    /// Discover a specific model by ID
    /// - Parameter modelId: Model identifier (e.g., "mlx-community/model-name")
    /// - Returns: Discovered model with backends detected and model card loaded
    func discoverModel(_ modelId: String) async throws -> DiscoveredModel

    // MARK: - Search Functionality

    /// Search models with pagination support
    /// - Parameters:
    ///   - query: Search query
    ///   - author: Filter by author
    ///   - tags: Filter by tags
    ///   - sort: Sort option
    ///   - direction: Sort direction
    ///   - limit: Results per page
    ///   - cursor: Pagination cursor
    /// - Returns: Page of models
    func searchPaginated(
        query: String?,
        author: String?,
        tags: [String],
        cursor: String?,
        sort: SortOption,
        direction: SortDirection,
        limit: Int
    ) async throws -> ModelPage

    /// Search models by tags
    /// - Parameters:
    ///   - tags: Tags to search for
    ///   - community: Optional community filter
    ///   - sort: Sort option
    ///   - limit: Maximum results
    /// - Returns: Array of discovered models
    func searchByTags(
        _ tags: [String],
        community: ModelCommunity?,
        sort: SortOption,
        limit: Int
    ) async throws -> [DiscoveredModel]

    // MARK: - Model Preparation

    /// Convert a discovered model to SendableModel for download
    /// - Parameters:
    ///   - model: The discovered model
    ///   - preferredBackend: Optional preferred backend
    /// - Returns: SendableModel ready for download
    func prepareForDownload(
        _ model: DiscoveredModel,
        preferredBackend: SendableModel.Backend?
    ) async throws -> SendableModel

    /// Get model info preview without downloading
    /// - Parameter model: The discovered model
    /// - Returns: ModelInfo for preview
    func getModelPreview(_ model: DiscoveredModel) async -> ModelInfo

    // MARK: - Image Enhancement

    /// Populate image URLs for a discovered model with lazy loading
    /// 
    /// This method extracts image URLs from the model's card content and metadata,
    /// applying intelligent filtering to exclude badges and logos. For converted
    /// models, it may fall back to the original model's images.
    /// 
    /// The method implements lazy loading to avoid performance impact on list views.
    /// Call this method only when images are actually needed (e.g., detail views).
    /// 
    /// - Parameter model: The discovered model to enhance with images
    /// - Returns: Updated model with populated imageUrls property
    /// - Throws: ImageExtractionError for network or parsing failures
    func populateImages(for model: DiscoveredModel) async throws -> DiscoveredModel

    // MARK: - Model Enhancement

    /// Enrich a model with complete data including model card and cardData
    ///
    /// This method takes a basic DiscoveredModel (typically from search results)
    /// and enhances it with detailed information fetched from the HuggingFace API.
    /// This includes model card content, comprehensive metadata, and images.
    ///
    /// - Parameter model: Basic model from search results
    /// - Returns: Enhanced model with complete data
    /// - Throws: HuggingFaceError for API failures
    func enrichModel(_ model: DiscoveredModel) async throws -> DiscoveredModel

    /// Enrich multiple models concurrently with detailed data
    ///
    /// This method processes multiple models in parallel for better performance.
    /// If individual model enrichment fails, the original model is returned.
    ///
    /// - Parameter models: Array of basic models from search results
    /// - Returns: Array of enhanced models with complete data
    func enrichModels(_ models: [DiscoveredModel]) async -> [DiscoveredModel]
}
