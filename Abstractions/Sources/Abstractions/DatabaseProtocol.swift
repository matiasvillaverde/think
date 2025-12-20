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
}
