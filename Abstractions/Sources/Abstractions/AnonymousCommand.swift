import Foundation
import SwiftData

/// Protocol for anonymous database commands that don't require user context
public protocol AnonymousCommand: Command {
    func execute(in context: ModelContext) throws -> Result
}
