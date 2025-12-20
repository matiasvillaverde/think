import Foundation

/// Strategy for processing file content during RAG operations
///
/// Defines how text content should be processed before vectorization and storage.
/// Different strategies optimize for different use cases:
/// - `extractKeywords`: Focuses on key terms for better semantic matching
/// - `fullText`: Preserves complete content for comprehensive search
public enum FileProcessingStrategy: Sendable {
    /// Extract only keywords (verbs, adjectives, nouns) for focused semantic matching
    case extractKeywords

    /// Use complete text content for comprehensive search capabilities
    case fullText

    /// Debug description explaining the processing strategy
    public var debugDescription: String {
        switch self {
        case .extractKeywords:
            return "Strategy: Extract verbs, adjectives and nouns"
        case .fullText:
            return "Strategy: Use full text"
        }
    }
}
