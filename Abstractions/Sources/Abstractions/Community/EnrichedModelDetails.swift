import Foundation

/// Container for enriched model data used during progressive loading
///
/// This struct holds the detailed information that's fetched asynchronously
/// and used to enrich DiscoveredModel instances. It enables a two-phase
/// loading pattern where basic model information is loaded first for quick
/// UI display, followed by detailed enrichment for enhanced functionality.
///
/// ## Progressive Loading Pattern
/// ```swift
/// // Phase 1: Basic model creation with fast-loading data
/// let model = DiscoveredModel(id: "model-id", name: "Model Name", ...)
/// 
/// // Phase 2: Asynchronous enrichment with detailed data
/// let details = EnrichedModelDetails(
///     modelCard: "# Model Card\n\nDetailed description...",
///     cardData: ModelCardData(...),
///     imageUrls: ["https://example.com/image1.jpg"],
///     detectedBackends: [.mlx, .coreML]
/// )
/// await model.enrich(with: details)
/// ```
public struct EnrichedModelDetails: Sendable {
    /// The model card (README) content in markdown format
    ///
    /// Contains detailed documentation about the model including:
    /// - Model description and intended use
    /// - Training details and datasets
    /// - Performance metrics and benchmarks
    /// - Usage examples and code snippets
    public let modelCard: String?

    /// Comprehensive card data metadata from HuggingFace API
    ///
    /// Structured metadata including licensing, relationships,
    /// technical specifications, and visual content references.
    public let cardData: ModelCardData?

    /// Image URLs extracted from model card or original model
    ///
    /// Contains absolute URLs to relevant images such as:
    /// - Architecture diagrams
    /// - Sample outputs/examples
    /// - Performance charts
    /// Excludes badges, logos, and other decorative elements.
    public let imageUrls: [String]

    /// Detected backend support based on file analysis
    ///
    /// Automatically determined support for different inference backends
    /// based on the presence of specific model files (e.g., .mlx, .safetensors, .gguf).
    public let detectedBackends: [SendableModel.Backend]

    /// Initialize enriched model details
    /// - Parameters:
    ///   - modelCard: The model card content
    ///   - cardData: Structured metadata from HuggingFace API
    ///   - imageUrls: Array of relevant image URLs
    ///   - detectedBackends: Array of supported inference backends
    public init(
        modelCard: String? = nil,
        cardData: ModelCardData? = nil,
        imageUrls: [String] = [],
        detectedBackends: [SendableModel.Backend] = []
    ) {
        self.modelCard = modelCard
        self.cardData = cardData
        self.imageUrls = imageUrls
        self.detectedBackends = detectedBackends
    }
}
