// swiftlint:disable line_length
import Abstractions
import Database
import Foundation
import OSLog

/// Actor responsible for managing file attachments in the view layer
///
/// This actor provides a simplified interface for processing, displaying errors,
/// and deleting file attachments with appropriate user notifications.
public final actor ViewModelAttacher: ViewModelAttaching {
    // MARK: - Properties

    /// Database interface for persistent storage
    private let database: DatabaseProtocol

    /// Logger for debugging and tracking operations
    private let logger: Logger = Logger(
        subsystem: "ViewModels",
        category: String(describing: ViewModelAttacher.self)
    )

    // MARK: - Initialization

    /// Initializes a new ViewModelAttacher with required dependencies
    /// - Parameters:
    ///   - database: The database interface for persistent storage
    ///   - chatId: The UUID of the chat where files will be attached
    public init(database: DatabaseProtocol) {
        self.database = database
        logger.debug("ViewModelAttacher initialized")
    }

    // MARK: - Public API Implementation

    /// Processes a file for attachment to the current chat
    /// - Parameter file: The URL of the file to process
    public func process(file: URL, chatId: UUID) async {
        logger.debug("Processing file: \(file.lastPathComponent)")

        do {
            let fileId: UUID = try await database.write(FileCommands.Create(
                fileURL: file,
                chatId: chatId,
                database: database
            ))

            logger.info("Successfully attached file: \(file.lastPathComponent), id: \(fileId.uuidString)")
            await notify(message: String(localized: "File successfully attached", bundle: .module), type: .success)
        } catch {
            logger.error("Failed to process file: \(file.lastPathComponent), error: \(error.localizedDescription)")
            await show(error: error)
        }
    }

    /// Displays an error to the user via the notification system
    /// - Parameter error: The error to display
    public func show(error: any Error) async {
        logger.error("Showing error: \(error.localizedDescription)")
        await notify(message: error.localizedDescription, type: .error)
    }

    /// Deletes a file attachment
    /// - Parameter file: The UUID of the file to delete
    public func delete(file: UUID) async {
        logger.debug("Deleting file: \(file.uuidString)")

        do {
            _ = try await database.write(FileCommands.Delete(fileId: file))

            logger.info("Successfully deleted file: \(file.uuidString)")
            await notify(message: String(localized: "File successfully deleted", bundle: .module), type: .success)
        } catch {
            logger.error("Failed to delete file: \(file.uuidString), error: \(error.localizedDescription)")
            await show(error: error)
        }
    }

    // MARK: - Private Methods

    /// Sends a notification to the user
    /// - Parameters:
    ///   - message: The notification message
    ///   - type: The type of notification (success, error, info, etc.)
    private func notify(message: String, type: NotificationType) async {
        _ = try? await database.write(
            NotificationCommands.Create(
                type: type,
                message: message
            )
        )
    }
}
// swiftlint:enable line_length
