import Foundation
import SwiftData

/// Base protocol for all database commands
public protocol Command: Sendable {
    associatedtype Result

    var requiresUser: Bool { get }
    var requiresRag: Bool { get }

    func execute(
        in context: ModelContext,
        userId: PersistentIdentifier?,
        rag: Ragging?
    ) throws -> Result
}
