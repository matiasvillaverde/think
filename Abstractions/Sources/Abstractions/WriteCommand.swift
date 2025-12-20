import Foundation
import SwiftData

/// Protocol for database write commands that return a UUID
public protocol WriteCommand: Command where Result == UUID {
    func execute(
        in context: ModelContext,
        userId: PersistentIdentifier?,
        rag: Ragging?
    ) throws -> UUID
}
