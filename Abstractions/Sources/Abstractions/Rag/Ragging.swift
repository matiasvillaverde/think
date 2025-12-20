import Foundation

/// Protocol for Retrieval-Augmented Generation (RAG) operations
///
/// This actor-based protocol provides thread-safe operations for building and querying
/// vector databases. It supports multiple loading strategies, file and text ingestion,
/// semantic search, and database management operations.
///
/// ## Usage Example
/// ```swift
/// let rag = try await SomeRagImplementation(
///     from: "sentence-transformers/all-MiniLM-L6-v2",
///     local: nil,
///     useBackgroundSession: true,
///     database: .temporary
/// )
/// 
/// // Add documents
/// for await progress in rag.add(text: "Sample text", id: UUID(), configuration: config) {
///     print("Progress: \(progress.fractionCompleted)")
/// }
/// 
/// // Search for similar content
/// let results = try await rag.semanticSearch(
///     query: "search query",
///     numResults: 5,
///     threshold: 0.7,
///     table: "documents"
/// )
/// ```
public protocol Ragging: Actor, Sendable {
    init(
        from hubRepoId: String,
        local: URL?,
        useBackgroundSession: Bool,
        database: DatabaseLocation,
        loadingStrategy: RagLoadingStrategy
    ) async throws

    init(
        from hubRepoId: String,
        local: URL?,
        useBackgroundSession: Bool,
        database: DatabaseLocation
    ) async throws

    func add(
        fileURL: URL,
        id: UUID,
        configuration: Configuration
    ) -> AsyncThrowingStream<Progress, Error>

    func add(
        text: String,
        id: UUID,
        configuration: Configuration
    ) -> AsyncThrowingStream<Progress, Error>

    func semanticSearch(
        query: String,
        numResults: Int,
        threshold: Double,
        table: String
    ) async throws -> [SearchResult]

    func getChunk(
        index: Int,
        table: String
    ) async throws -> SearchResult

    func deleteTable(
        _ table: String
    ) async throws

    func deleteAll() async throws

    func delete(
        id: UUID,
        table: String
    ) async throws
}
