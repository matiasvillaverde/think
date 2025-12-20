import Foundation

/// Constants for RAG configuration
public enum Constants {
    /// Default table name for embeddings storage
    public static let defaultTable = "embeddings"
    /// Default dimension for embedding vectors
    public static let defaultEmbeddingDimension = 384
    /// Default maximum distance threshold for semantic search
    public static let defaultSearchThreshold: Double = 10.0
    /// Default number of search results to return
    public static let defaultSearchResultCount: Int = 1
    /// Maximum number of search results for broad queries
    public static let maxSearchResultCount: Int = 5
}
