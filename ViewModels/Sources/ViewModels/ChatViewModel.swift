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

    /// Animates a welcome message word by word
    /// - Parameters:
    ///   - messageId: The message ID to update
    ///   - welcomeMessage: The welcome message text
    private func animateWelcomeMessage(
        messageId: UUID,
        welcomeMessage: String
    ) async throws {
        // Create haptic feedback generator for iOS
        #if os(iOS)
        let lightFeedbackGenerator: UIImpactFeedbackGenerator = await UIImpactFeedbackGenerator(style: .light)
        let mediumFeedbackGenerator: UIImpactFeedbackGenerator = await  UIImpactFeedbackGenerator(style: .medium)
        // Prepare generators ahead of time for more responsive feedback
        await lightFeedbackGenerator.prepare()
        await mediumFeedbackGenerator.prepare()
        #endif

        // Break up the message into words and add them with a delay to simulate typing
        let words: [Substring] = welcomeMessage.split(separator: " ")
        var currentResponse: String = ""

        for (index, word) in words.enumerated() {
            // Add the word to the current response
            if index > 0 {
                currentResponse += " "
            }
            currentResponse += word

            // Update the message with the current response
            let output: ProcessedOutput = ProcessedOutput(
                channels: [
                    ChannelMessage(
                        id: UUID(),
                        type: .final,
                        content: currentResponse,
                        order: 0
                    )
                ]
            )
            try await database.write(MessageCommands.UpdateProcessedOutput(
                messageId: messageId,
                processedOutput: output
            ))

            // Add haptic feedback on iOS only
            #if os(iOS)
            // Alternate between light and medium feedback for a more natural feel
            // End of message gets a medium feedback
            if index == words.count - 1 {
                await mediumFeedbackGenerator.impactOccurred()
            } else if index.isMultiple(of: Self.hapticFeedbackInterval) {
                await lightFeedbackGenerator.impactOccurred(intensity: Self.mediumFeedbackIntensity)
            } else {
                await lightFeedbackGenerator.impactOccurred(intensity: Self.lightFeedbackIntensity)
            }
            #endif

            // Vary the delay to make typing seem more natural (80-180ms)
            let typingDelay: UInt64 = UInt64.random(in: Self.minTypingDelayNanoseconds...Self.maxTypingDelayNanoseconds)
            try await Task.sleep(nanoseconds: typingDelay)
        }
    }

    /// Adds a welcome message to the chat if it's empty with haptic feedback on iOS
    /// - Parameter chatId: The UUID of the chat to add the welcome message to
    public func addWelcomeMessage(chatId: UUID) async {
        do {
            // Check if the chat is empty
            let existingMessages: Int = try await database.read(MessageCommands.CountMessages(chatId: chatId))

            // Only add welcome message if there are no existing messages
            if existingMessages == 0 {
                logger.info("Adding welcome message to empty chat: \(chatId)")

                let welcomeMessage: String = String(localized: "How can I help you today?", bundle: .module)

                // Create the initial empty message
                let messageId: UUID = try await database.write(MessageCommands.Create(
                    chatId: chatId,
                    userInput: nil,
                    isDeepThinker: false
                ))

                // Animate the welcome message
                try await animateWelcomeMessage(
                    messageId: messageId,
                    welcomeMessage: welcomeMessage
                )

                logger.info("Welcome message added successfully to chat: \(chatId)")
            } else {
                logger.info("Skipping welcome message for non-empty chat: \(chatId)")
            }
        } catch {
            // Log error but don't show a notification to the user
            logger.error("Failed to add welcome message to chat \(chatId): \(error.localizedDescription)")
        }
    }

    /// Creates a new custom personality
    /// - Parameters:
    ///   - name: The name of the new personality
    ///   - description: The description of the personality
    ///   - customSystemInstruction: The custom system instruction text
    ///   - category: The personality category
    ///   - tintColorHex: Optional hex color string for the personality
    ///   - imageName: Optional system image name
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
