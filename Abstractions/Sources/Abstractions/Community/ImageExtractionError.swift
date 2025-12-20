import Foundation

/// Errors that can occur during image extraction from model cards and metadata
///
/// This error type covers various failure modes when extracting image URLs
/// from HuggingFace model repositories, including network issues, parsing
/// problems, and validation failures.
///
/// ## Common Error Scenarios
/// - **Network errors**: API timeouts, connectivity issues, rate limiting
/// - **Parsing errors**: Malformed JSON, invalid HTML/Markdown structure
/// - **Validation errors**: Invalid model IDs, malformed URLs
/// - **Recursion limits**: Infinite loops when following model references
///
/// ## Usage
/// ```swift
/// do {
///     let imageUrls = try await extractor.extractImageUrls(from: "model-id")
/// } catch let error as ImageExtractionError {
///     switch error {
///     case .networkError(let message):
///         print("Network failed: \(message)")
///     case .parsingError(let message):
///         print("Failed to parse: \(message)")
///     case .invalidModelId(let modelId):
///         print("Invalid model: \(modelId)")
///     }
/// }
/// ```
public enum ImageExtractionError: LocalizedError, Equatable {
    /// Network communication failed during API requests
    case networkError(String)

    /// Failed to parse response content (JSON, HTML, Markdown)
    case parsingError(String)

    /// Model ID format is invalid or unsupported
    case invalidModelId(String)

    /// Maximum recursion depth exceeded while following model references
    case recursionLimitExceeded

    /// URL format validation failed
    case invalidUrl(String)

    /// Localized error description for user display
    public var errorDescription: String? {
        switch self {
        case .networkError(let message):
            return "Network error during image extraction: \(message)"
        case .parsingError(let message):
            return "Parsing error: \(message)"
        case .invalidModelId(let modelId):
            return "Invalid model ID: \(modelId)"
        case .recursionLimitExceeded:
            return "Maximum recursion depth exceeded while following model references"
        case .invalidUrl(let url):
            return "Invalid URL: \(url)"
        }
    }
}
