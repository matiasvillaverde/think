import Foundation

/// Protocol for extracting image URLs from model cards and metadata
///
/// This protocol defines the interface for extracting visual content from
/// HuggingFace model repositories, including both structured metadata and
/// model card content parsing.
///
/// The protocol supports:
/// - Structured metadata extraction (preferred)
/// - Markdown/HTML image parsing with filtering
/// - Original model reference detection for converted models
/// - URL resolution from relative to absolute paths
///
/// ## Example Usage
/// ```swift
/// let extractor: ImageExtractorProtocol = ImageExtractor()
/// 
/// // Extract images from a model
/// let imageUrls = try await extractor.extractImageUrls(from: "mlx-community/model")
/// 
/// // Check for original model reference
/// let originalId = extractor.findOriginalModelId(from: modelCard)
/// ```
public protocol ImageExtractorProtocol: Sendable {
    // MARK: - Image Extraction

    /// Extract image URLs from model metadata and card content
    /// 
    /// This method first checks structured metadata for image references,
    /// then falls back to parsing the model card content. It automatically
    /// filters out irrelevant images (badges, logos) and resolves relative
    /// URLs to absolute HuggingFace paths.
    /// 
    /// - Parameter modelId: Model identifier (e.g., "mlx-community/model-name")
    /// - Returns: Array of absolute image URLs, filtered for relevance
    /// - Throws: NetworkError for API failures, ParsingError for malformed content
    func extractImageUrls(from modelId: String) async throws -> [String]

    /// Extract image URLs from model card content with filtering
    /// 
    /// Parses markdown and HTML image references from the provided content,
    /// applying intelligent filtering to exclude badges, logos, and other
    /// non-informative images.
    /// 
    /// - Parameters:
    ///   - modelCard: Model card content to parse
    ///   - modelId: Model ID for URL resolution
    /// - Returns: Array of filtered absolute image URLs
    func extractImageUrls(from modelCard: String, modelId: String) -> [String]

    // MARK: - Original Model Detection

    /// Find original model reference for converted models
    /// 
    /// First checks structured metadata (config.json, cardData.source_model),
    /// then falls back to parsing conversion text patterns in the model card.
    /// Implements recursion protection to prevent infinite loops.
    /// 
    /// - Parameter modelId: The model ID to check for original references
    /// - Returns: Original model ID if found, nil otherwise
    /// - Throws: NetworkError for API failures
    func findOriginalModelId(from modelId: String) async throws -> String?

    /// Find original model reference from model card text
    /// 
    /// Parses text patterns like "converted from X" to identify the
    /// original model that contains more comprehensive visual content.
    /// 
    /// - Parameter modelCard: Model card content to parse
    /// - Returns: Original model ID if conversion reference found, nil otherwise
    func findOriginalModelId(from modelCard: String?) -> String?

    // MARK: - URL Resolution

    /// Resolve relative image URLs to absolute HuggingFace URLs
    /// 
    /// Converts relative paths to fully qualified HuggingFace URLs using
    /// the standard resolve pattern: https://huggingface.co/{modelId}/resolve/main/{path}
    /// 
    /// - Parameters:
    ///   - imagePath: Relative or absolute image path
    ///   - modelId: Model ID for URL resolution
    /// - Returns: Absolute URL string, or original if already absolute
    func resolveImageUrl(_ imagePath: String, for modelId: String) -> String
}
