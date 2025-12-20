import Foundation

/// Configuration for chunking text into overlapping token windows.
public struct ChunkingConfiguration: Sendable, Equatable {
    public let maxTokens: Int
    public let overlap: Int

    public init(maxTokens: Int, overlap: Int) {
        let normalizedMaxTokens: Int = max(1, maxTokens)
        let normalizedOverlap: Int = min(max(0, overlap), normalizedMaxTokens - 1)

        self.maxTokens = normalizedMaxTokens
        self.overlap = normalizedOverlap
    }

    /// Disables chunking by allowing a single chunk up to Int.max tokens.
    public static let disabled = ChunkingConfiguration(maxTokens: Int.max, overlap: 0)

    /// Recommended chunking for file ingestion.
    public static let fileDefault = ChunkingConfiguration(maxTokens: 64, overlap: 8)
}
