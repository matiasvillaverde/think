// swiftlint:disable line_length
import Abstractions
import Database
import Foundation
import OSLog
#if os(iOS)
import UIKit
#endif

/// Actor responsible for managing chat operations in the view layer
///
/// This actor provides a thread-safe interface for performing chat-related operations
/// such as creating, deleting, and renaming chats. It handles all database interactions
/// and provides user feedback through the notification system.
public final actor ChatViewModel: ChatViewModeling {
    // MARK: - Constants

    /// Light haptic feedback intensity for iOS
    private static let lightFeedbackIntensity: CGFloat = 0.4

    /// Medium haptic feedback intensity for iOS
    private static let mediumFeedbackIntensity: CGFloat = 0.6

    /// Minimum typing delay in nanoseconds (80ms)
    private static let minTypingDelayNanoseconds: UInt64 = 80_000_000

    /// Maximum typing delay in nanoseconds (180ms)
    private static let maxTypingDelayNanoseconds: UInt64 = 180_000_000

    /// Interval for alternating haptic feedback (every 2 words)
    private static let hapticFeedbackInterval: Int = 2

    // MARK: - Properties

    /// Database interface for persistent storage
    private let database: DatabaseProtocol

    /// Logger for debugging and tracking operations
    private let logger: Logger = Logger(subsystem: "ViewModels", category: "ChatViewModel")

    // MARK: - Initialization

    /// Initializes a new ChatViewModel with required dependencies
    /// - Parameter database: The database interface for persistent storage
    public init(database: DatabaseProtocol) {
        self.database = database
        logger.info("ChatViewModel initialized")
    }

    // MARK: - Public API Implementation

    /// Creates a new chat in the database
    /// - Returns: The ID of the newly created chat (or nil if creation failed)
    public func addChatWith(personality: UUID) async {
        do {
            let chatId: UUID = try await database.write(ChatCommands.Create(personality: personality))
            logger.info("Created new chat with ID: \(chatId)")

            Task(priority: .background) {
                do {
                    try await database.writeInBackground(ChatCommands.AutoRenameFromContent(chatId: chatId))
                    logger.info("Auto rename chats titles")
                } catch {
                    logger.error("Failed to auto-rename chat: \(error.localizedDescription)")
                }
            }
        } catch {
            logger.error("Failed to create chat: \(error.localizedDescription)")
            await notify(message: error.localizedDescription, type: .error)
        }
    }

    /// Deletes a chat with the given ID
    /// - Parameter chatId: The UUID of the chat to delete
    /// - Returns: Boolean indicating whether the deletion was successful
    public func delete(chatId: UUID) async {
        do {
            try await database.write(ChatCommands.Delete(id: chatId))
            logger.info("Deleted chat with ID: \(chatId)")
            await notify(message: String(localized: "Chat deleted", bundle: .module), type: .success)
        } catch {
            logger.error("Failed to delete chat \(chatId): \(error.localizedDescription)")
            await notify(message: error.localizedDescription, type: .error)
        }
    }

    public func deleteAll() async {
        do {
            try await database.write(ChatCommands.ResetAllChats(systemInstruction: .englishAssistant))
            logger.info("All chats deleted")
        } catch {
            logger.error("Failed to delete all chats: \(error.localizedDescription)")
            await notify(message: error.localizedDescription, type: .error)
        }
    }

    /// Renames a chat with the given ID
    /// - Parameters:
    ///   - chatId: The UUID of the chat to rename
    ///   - newName: The new name for the chat
    public func rename(chatId: UUID, newName: String) async {
        do {
            try await database.write(ChatCommands.Rename(chatId: chatId, newName: newName))
            logger.info("Renamed chat \(chatId) to '\(newName)'")
            await notify(message: String(localized: "Chat renamed", bundle: .module), type: .success)
        } catch {
            logger.error("Failed to rename chat \(chatId): \(error.localizedDescription)")
            await notify(message: error.localizedDescription, type: .error)
        }
    }

    /// Creates a new custom personality
    /// - Parameters:
    ///   - name: The name of the new personality
    ///   - description: The description of the personality
    ///   - customSystemInstruction: The custom system instruction text
    ///   - category: The personality category
    ///   - customImage: Optional custom image attachment
    /// - Returns: The UUID of the newly created personality
    public func createPersonality(
        name: String,
        description: String,
        customSystemInstruction: String,
        category: PersonalityCategory,
        customImage: Data?
    ) async -> UUID? {
        do {
            let personalityId: UUID = try await database.write(PersonalityCommands.CreateCustom(
                name: name,
                description: description,
                customSystemInstruction: customSystemInstruction,
                category: category,
                customImage: customImage
            ))
            logger.info("Created new personality with ID: \(personalityId)")
            return personalityId
        } catch {
            logger.error("Failed to create personality: \(error.localizedDescription)")
            await notify(message: error.localizedDescription, type: .error)
            return nil
        }
    }

    // MARK: - Personality-First Operations

    /// Selects a personality and ensures its chat is ready
    public func selectPersonality(personalityId: UUID) async {
        do {
            // Get or create the chat for this personality
            let chatId: UUID = try await database.write(PersonalityCommands.GetChat(personalityId: personalityId))
            logger.info("Selected personality \(personalityId) with chat \(chatId)")
        } catch {
            logger.error("Failed to select personality \(personalityId): \(error.localizedDescription)")
            await notify(message: error.localizedDescription, type: .error)
        }
    }

    /// Clears all messages from a personality's conversation
    public func clearConversation(personalityId: UUID) async {
        do {
            try await database.write(PersonalityCommands.ClearConversation(personalityId: personalityId))
            logger.info("Cleared conversation for personality: \(personalityId)")
            await notify(
                message: String(localized: "Conversation cleared", bundle: .module),
                type: .success
            )
        } catch {
            logger.error("Failed to clear conversation for \(personalityId): \(error.localizedDescription)")
            await notify(message: error.localizedDescription, type: .error)
        }
    }

    /// Deletes a custom personality and its associated chat
    public func deletePersonality(personalityId: UUID) async {
        do {
            try await database.write(PersonalityCommands.Delete(personalityId: personalityId))
            logger.info("Deleted personality: \(personalityId)")
            await notify(
                message: String(localized: "Personality deleted", bundle: .module),
                type: .success
            )
        } catch {
            logger.error("Failed to delete personality \(personalityId): \(error.localizedDescription)")
            await notify(message: error.localizedDescription, type: .error)
        }
    }

    // MARK: - Helper Methods

    /// Sends a notification to the user
    /// - Parameters:
    ///   - message: The notification message
    ///   - type: The type of notification (success, error, warning, info)
    private func notify(message: String, type: NotificationType) async {
        do {
            try await database.write(
                NotificationCommands.Create(
                    type: type,
                    message: message
                )
            )
        } catch {
            logger.error("Failed to create notification: \(error.localizedDescription)")
        }
    }
}
// swiftlint:enable line_length
