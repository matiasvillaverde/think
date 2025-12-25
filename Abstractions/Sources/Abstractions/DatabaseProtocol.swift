import Foundation

/// Protocol defining the public interface for Database operations
public protocol DatabaseProtocol: Actor {
    /// The current status of the database
    @MainActor var status: DatabaseStatus { get }

    /// Executes a write command on the main actor
    @MainActor
    @discardableResult
    func write<T: WriteCommand>(_ command: T) async throws -> T.Result

    /// Executes a read command on the main actor
    @MainActor
    func read<T: ReadCommand>(_ command: T) async throws -> T.Result

    /// Executes an anonymous command on the main actor
    @MainActor
    @discardableResult
    func execute<T: AnonymousCommand>(_ command: T) async throws -> T.Result

    /// Saves changes to the database on the main actor
    @MainActor
    func save() throws

    /// Executes a write command in the background
    func writeInBackground<T: WriteCommand>(_ command: T) async throws

    /// Executes a read command in the background
    func readInBackground<T: ReadCommand>(_ command: T) async throws -> T.Result

    /// Performs semantic search on the database
    func semanticSearch(
        query: String,
        table: String,
        numResults: Int,
        threshold: Double
    ) async throws -> [SearchResult]

    /// Indexes text in RAG for semantic search
    /// - Parameters:
    ///   - text: The text to index
    ///   - id: The unique identifier for this text (e.g., memory ID)
    ///   - table: The RAG table to store the text in
    func indexText(
        _ text: String,
        id: UUID,
        table: String
    ) async throws

    /// Deletes indexed content from RAG
    /// - Parameters:
    ///   - id: The unique identifier of the content to delete
    ///   - table: The RAG table to delete from
    func deleteFromIndex(
        id: UUID,
        table: String
    ) async throws

    /// Performs semantic search on memories for a user
    /// - Parameters:
    ///   - query: The search query
    ///   - userId: The user's ID (used to determine the memory table)
    ///   - limit: Maximum number of results
    ///   - threshold: Similarity threshold (lower is more similar)
    /// - Returns: Array of memory IDs sorted by relevance
    func searchMemories(
        query: String,
        userId: UUID,
        limit: Int,
        threshold: Double
    ) async throws -> [UUID]
}
