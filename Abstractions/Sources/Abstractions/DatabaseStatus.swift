import Foundation

/// Represents the current status of the database
public enum DatabaseStatus: Equatable, Sendable {
    case new
    case partiallyReady
    case ready
    case failed(NSError)
}
