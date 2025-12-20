import Foundation
import SwiftData
import Abstractions

extension AppCommands {
    /// Command to delete all entities from the database
    /// Deletes entities in reverse dependency order to avoid constraint violations
    public struct DeleteAll: WriteCommand & AnonymousCommand {
        public init() {}

        public func execute(in context: ModelContext) -> UUID {
            // Delete in reverse dependency order to avoid constraint violations
            try? context.delete(model: Tag.self)
            try? context.delete(model: Model.self)
            try? context.delete(model: Metrics.self)
            try? context.delete(model: FileAttachment.self)
            try? context.delete(model: ImageAttachment.self)
            try? context.delete(model: Message.self)
            try? context.delete(model: DiffusorConfiguration.self)
            try? context.delete(model: LLMConfiguration.self)
            try? context.delete(model: Chat.self)
            try? context.delete(model: NotificationAlert.self)
            try? context.delete(model: Prompt.self)
            try? context.delete(model: User.self)

            // Return the user ID that was deleted or nil if no user existed
            return UUID()
        }
    }
}
