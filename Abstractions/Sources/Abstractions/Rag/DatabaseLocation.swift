import Foundation

/// Location configuration for RAG database storage
///
/// Specifies where the vector database should be stored during RAG operations.
/// Options range from temporary in-memory storage to persistent file-based storage.
public enum DatabaseLocation: Equatable, Sendable {
    /// Store database in memory only (lost on process termination)
    case inMemory

    /// Store database in temporary location (cleaned up by system)
    case temporary

    /// Store database at specific URI location for persistence
    case uri(String)

    /// Debug description explaining the database location
    public var debugDescription: String {
        switch self {
        case .inMemory:
            return "In-memory database"
        case .temporary:
            return "Temporary database"
        case .uri(let uri):
            return "Database at URI: \(uri)"
        }
    }
}
