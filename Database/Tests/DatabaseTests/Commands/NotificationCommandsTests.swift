import Testing
import Foundation
import SwiftData
@testable import Database
import AbstractionsTestUtilities
import Abstractions

@Suite("Notification Commands Tests")
struct NotificationCommandsTests {
    @Suite(.tags(.acceptance))
    struct BasicFunctionalityTests {
        @Test("Create error notification successfully")
        @MainActor
        func createErrorNotificationSuccess() async throws {
            // Given
            let config = DatabaseConfiguration(
                isStoredInMemoryOnly: true,
                allowsSave: true,
                ragFactory: MockRagFactory(mockRag: MockRagging())
            )

            let database = try Database.new(configuration: config)
            let type = NotificationType.error
            let message = "Test error notification"

            // When
            try await database.write(NotificationCommands.Create(
                type: type,
                message: message
            ))

            // Then
            // Get the ID from the creation command
            let notificationId = try await database.write(NotificationCommands.Create(
                type: type,
                message: message
            ))

            // Use the Read command to fetch the notification
            let notification = try await database.read(NotificationCommands.Read(id: notificationId))
            #expect(notification.type == type)
            #expect(notification.localizedMessage == message)
            #expect(notification.isRead == false)
        }

        @Test("Create success notification successfully")
        @MainActor
        func createSuccessNotificationSuccess() async throws {
            // Given
            let config = DatabaseConfiguration(
                isStoredInMemoryOnly: true,
                allowsSave: true,
                ragFactory: MockRagFactory(mockRag: MockRagging())
            )

            let database = try Database.new(configuration: config)
            let type = NotificationType.success
            let message = "Test success notification"

            // When
            let notificationId = try await database.write(NotificationCommands.Create(
                type: type,
                message: message
            ))

            // Then
            let notification = try await database.read(NotificationCommands.Read(id: notificationId))
            #expect(notification.type == type)
            #expect(notification.localizedMessage == message)
            #expect(notification.isRead == false)
        }

        @Test("Create warning notification successfully")
        @MainActor
        func createWarningNotificationSuccess() async throws {
            // Given
            let config = DatabaseConfiguration(
                isStoredInMemoryOnly: true,
                allowsSave: true,
                ragFactory: MockRagFactory(mockRag: MockRagging())
            )

            let database = try Database.new(configuration: config)
            let type = NotificationType.warning
            let message = "Test warning notification"

            // When
            let notificationId = try await database.write(NotificationCommands.Create(
                type: type,
                message: message
            ))

            // Then
            let notification = try await database.read(NotificationCommands.Read(id: notificationId))
            #expect(notification.type == type)
            #expect(notification.localizedMessage == message)
            #expect(notification.isRead == false)
        }

        @Test("Create information notification successfully")
        @MainActor
        func createInformationNotificationSuccess() async throws {
            // Given
            let config = DatabaseConfiguration(
                isStoredInMemoryOnly: true,
                allowsSave: true,
                ragFactory: MockRagFactory(mockRag: MockRagging())
            )

            let database = try Database.new(configuration: config)
            let type = NotificationType.information
            let message = "Test information notification"

            // When
            let notificationId = try await database.write(NotificationCommands.Create(
                type: type,
                message: message
            ))

            // Then
            let notification = try await database.read(NotificationCommands.Read(id: notificationId))
            #expect(notification.type == type)
            #expect(notification.localizedMessage == message)
            #expect(notification.isRead == false)
        }
    }

    @Suite(.tags(.edge))
    struct EdgeCasesTests {
        @Test("Create notification with empty message")
        @MainActor
        func createNotificationEmptyMessage() async throws {
            // Given
            let config = DatabaseConfiguration(
                isStoredInMemoryOnly: true,
                allowsSave: true,
                ragFactory: MockRagFactory(mockRag: MockRagging())
            )

            let database = try Database.new(configuration: config)
            let type = NotificationType.error
            let message = ""

            // When
            let notificationId = try await database.write(NotificationCommands.Create(
                type: type,
                message: message
            ))

            // Then
            let notification = try await database.read(NotificationCommands.Read(id: notificationId))
            #expect(notification.type == type)
            #expect(notification.localizedMessage.isEmpty)
        }

        @Test("Create notification with very long message")
        @MainActor
        func createNotificationLongMessage() async throws {
            // Given
            let config = DatabaseConfiguration(
                isStoredInMemoryOnly: true,
                allowsSave: true,
                ragFactory: MockRagFactory(mockRag: MockRagging())
            )

            let database = try Database.new(configuration: config)
            let type = NotificationType.warning
            let message = String(repeating: "Very long message. ", count: 100)

            // When
            let notificationId = try await database.write(NotificationCommands.Create(
                type: type,
                message: message
            ))

            // Then
            let notification = try await database.read(NotificationCommands.Read(id: notificationId))
            #expect(notification.type == type)
            #expect(notification.localizedMessage == message)
        }
    }

    @Test("Mark notification as read successfully")
    @MainActor
    func markNotificationAsReadSuccess() async throws {
        // Given
        let config = DatabaseConfiguration(
            isStoredInMemoryOnly: true,
            allowsSave: true,
            ragFactory: MockRagFactory(mockRag: MockRagging())
        )

        let database = try Database.new(configuration: config)
        let type = NotificationType.error
        let message = "Test notification to be marked as read"

        // Create a notification
        let notificationId = try await database.write(NotificationCommands.Create(
            type: type,
            message: message
        ))

        // Verify it's initially unread
        let initialNotification = try await database.read(NotificationCommands.Read(id: notificationId))
        #expect(initialNotification.isRead == false)

        // When
        try await database.write(NotificationCommands.MarkAsRead(id: notificationId))

        // Then
        let updatedNotification = try await database.read(NotificationCommands.Read(id: notificationId))
        #expect(updatedNotification.id == notificationId)
        #expect(updatedNotification.isRead == true)
        #expect(updatedNotification.localizedMessage == message)
        #expect(updatedNotification.type == type)
    }
}

// MARK: - Potential Improvements
/*
1. Additional Commands Needed:
   - Read: To fetch a notification by ID
   - GetAll: To fetch all notifications
   - MarkAsRead: To mark a notification as read
   - Delete: To remove a notification
   - DeleteAll: To remove all notifications
   - GetUnread: To fetch only unread notifications

2. Notification Validation:
   - No validation for maximum message length
   - No handling for duplicate notifications

3. Feature Gaps:
   - No notification grouping
   - No notification priority levels
   - No notification expiration
   - No notification categories or tags
   - No user-specific notifications
*/
