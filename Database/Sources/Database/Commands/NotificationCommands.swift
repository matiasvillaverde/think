import Foundation
import OSLog
import SwiftData
import Abstractions

// swiftlint:disable nesting

// **MARK: - Notification Commands**
public enum NotificationCommands {
    private static let logger = Logger(subsystem: "Database", category: "NotificationCommands")

    public struct Create: WriteCommand & AnonymousCommand {
        let type: NotificationType
        let message: String
        public var requiresRag: Bool { false }

        public init(type: NotificationType, message: String) {
            self.type = type
            self.message = message
        }

        public func execute(in context: ModelContext) throws -> UUID {
            let notification = NotificationAlert(
                type: type,
                message: message
            )

            NotificationCommands.logger.info("Creating notification: type=\(String(describing: type)), message=\(message)")
            
            context.insert(notification)
            try context.save()
            
            NotificationCommands.logger.debug("Notification created with ID: \(notification.id)")

            return notification.id
        }
    }

    public struct Read: ReadCommand {
        private let id: UUID

        public typealias Result = NotificationAlert

        public init(id: UUID) {
            self.id = id
        }

        public func execute(in context: ModelContext, userId: PersistentIdentifier?, rag: Ragging?) throws -> NotificationAlert {
            NotificationCommands.logger.debug("Reading notification with ID: \(id)")
            
            let descriptor = FetchDescriptor<NotificationAlert>(
                predicate: #Predicate<NotificationAlert> { $0.id == id }
            )

            guard let notification = try context.performFetch(descriptor).first else {
                NotificationCommands.logger.error("Notification not found: \(id)")
                throw DatabaseError.notificationNotFound
            }
            
            NotificationCommands.logger.debug(
                "Retrieved notification: type=\(String(describing: notification.type)), isRead=\(notification.isRead)"
            )

            return notification
        }
    }

    public struct MarkAsRead: WriteCommand & AnonymousCommand {
        private let id: UUID
        public var requiresRag: Bool { false }

        public init(id: UUID) {
            self.id = id
        }

        public func execute(in context: ModelContext) throws -> UUID {
            NotificationCommands.logger.debug("Marking notification as read: \(id)")
            
            let descriptor = FetchDescriptor<NotificationAlert>(
                predicate: #Predicate<NotificationAlert> { $0.id == id }
            )

            guard let notification = try context.performFetch(descriptor).first else {
                NotificationCommands.logger.error("Cannot mark as read - notification not found: \(id)")
                throw DatabaseError.notificationNotFound
            }

            notification.isRead = true
            try context.save()
            
            NotificationCommands.logger.info(
                "Notification marked as read: type=\(String(describing: notification.type)), message=\(notification.localizedMessage)"
            )

            return notification.id
        }
    }
}
