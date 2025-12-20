// swiftlint:disable line_length
import Abstractions
import Database
import Foundation
import OSLog
#if os(iOS)
import UIKit
#endif

/// A view model responsible for managing notification-related operations.
/// Thread-safe actor that handles notification state updates through database operations.
public final actor NotificationViewModel: ViewModelNotifying {
    // MARK: - Constants

    /// Nanoseconds per second multiplier
    private static let nanosecondsPerSecond: UInt64 = 1_000_000_000

    /// Read delay in seconds
    private static let markAsReadDelaySeconds: UInt64 = 5

    /// Delay before marking notification as read in nanoseconds (5 seconds)
    private static let markAsReadDelayNanoseconds: UInt64 = nanosecondsPerSecond * markAsReadDelaySeconds

    private let database: DatabaseProtocol
    private let logger: Logger = Logger(
        subsystem: "ViewModels",
        category: String(describing: NotificationViewModel.self)
    )

    /// Initializes a new notification view model.
    /// - Parameter database: The database implementation for persistence operations.
    public init(database: DatabaseProtocol) {
        self.database = database
        logger.debug("NotificationViewModel initialized with database: \(String(describing: type(of: database)))")
    }

    /// Marks a notification as read in the database.
    /// - Parameter notification: The unique identifier of the notification to mark as read.
    public func markNotificationAsRead(_ notification: UUID) async {
        logger.debug("Marking notification as read: \(notification.uuidString)")

        do {
            try await Task.sleep(nanoseconds: Self.markAsReadDelayNanoseconds)
            try await database.write(NotificationCommands.MarkAsRead(id: notification))
            logger.info("Successfully marked notification as read: \(notification.uuidString)")
        } catch {
            // Handle unexpected errors
            logger.error("Failed to mark notification as read: \(notification.uuidString), error: \(error.localizedDescription)")
        }
    }

    public func showMessage(_ message: String) async {
        logger.debug("showMessage notification \(message)")

        do {
            try await database.write(NotificationCommands.Create(type: .success, message: message))
            logger.info("Successfully created notification: \(message)")
            #if os(iOS)
            // Medium impact when toggling the state
            let impactGenerator: UIImpactFeedbackGenerator = await UIImpactFeedbackGenerator(
                style: .heavy
            )
            await impactGenerator.prepare()
            await impactGenerator.impactOccurred()
            #endif
        } catch {
            // Handle unexpected errors
            logger.error("Failed to create notification: \(message), error: \(error.localizedDescription)")
        }
    }
}
// swiftlint:enable line_length
