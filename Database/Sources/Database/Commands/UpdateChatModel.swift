import Foundation
import SwiftData
import OSLog
import Abstractions

// swiftlint:disable line_length

extension ChatCommands {
    /// Command to update a chat with a new model based on the model type
    public struct UpdateChatModel: WriteCommand {
        // MARK: - Properties

        /// Logger for chat model update operations
        private static let logger = Logger(
            subsystem: "Database",
            category: "UpdateChatModel"
        )

        let chatId: UUID
        let modelId: UUID

        // MARK: - Initialization

        /// Initialize a new command to update a chat's model
        /// - Parameters:
        ///   - chatId: The UUID of the chat to update
        ///   - modelId: The UUID of the model to set
        public init(chatId: UUID, modelId: UUID) {
            Self.logger.info("UpdateChatModel command created - Chat: \(chatId), Model: \(modelId)")
            self.chatId = chatId
            self.modelId = modelId
        }

        // MARK: - Command Execution

        public func execute(
            in context: ModelContext,
            userId: PersistentIdentifier?,
            rag: Ragging?
        ) throws -> UUID {
            Self.logger.notice("Starting chat model update - Chat: \(chatId), Model: \(modelId)")

            let startTime = CFAbsoluteTimeGetCurrent()

            do {
                // Log user context if available
                if let userId = userId {
                    Self.logger.debug("Executing for user: \(userId.storeIdentifier ?? "Unknown")")
                } else {
                    Self.logger.debug("Executing without specific user context")
                }

                // Log RAG context if available
                if rag != nil {
                    Self.logger.debug("RAG context available for operation")
                } else {
                    Self.logger.debug("No RAG context provided")
                }

                // Fetch the chat
                Self.logger.info("Fetching chat with ID: \(chatId)")
                let chatDescriptor = FetchDescriptor<Chat>(
                    predicate: #Predicate<Chat> { $0.id == chatId }
                )

                guard let chat = try context.fetch(chatDescriptor).first else {
                    Self.logger.error("Chat not found with ID: \(chatId)")
                    throw DatabaseError.chatNotFound
                }

                Self.logger.info("Chat found - Title: \(chat.id.uuidString, privacy: .public)")
                Self.logger.debug("Current chat models - Language: \(chat.languageModel.name, privacy: .public), Image: \(chat.imageModel.name, privacy: .public)")

                // Fetch the new model
                Self.logger.info("Fetching model with ID: \(modelId)")
                let modelDescriptor = FetchDescriptor<Model>(
                    predicate: #Predicate<Model> { $0.id == modelId }
                )

                guard let newModel = try context.fetch(modelDescriptor).first else {
                    Self.logger.error("Model not found with ID: \(modelId)")
                    throw DatabaseError.modelNotFound
                }

                Self.logger.info("Model found - Name: \(newModel.name, privacy: .public), Type: \(String(describing: newModel.type), privacy: .public)")
                Self.logger.debug("Model details - RAM: \(newModel.ramNeeded), State: \(String(describing: newModel.state))")

                // Store previous model information for logging
                var previousModelName: String = ""
                var updateType: String = ""

                // Update the appropriate model based on type
                Self.logger.info("Updating chat model based on type: \(String(describing: newModel.type), privacy: .public)")

                switch newModel.type {
                case .language, .visualLanguage, .flexibleThinker, .deepLanguage:
                    previousModelName = chat.languageModel.name
                    updateType = "Language Model"
                    Self.logger.debug("Updating language model from '\(previousModelName, privacy: .public)' to '\(newModel.name, privacy: .public)'")
                    chat.languageModel = newModel

                case .diffusion, .diffusionXL:
                    previousModelName = chat.imageModel.name
                    updateType = "Image Model"
                    Self.logger.debug("Updating image model from '\(previousModelName, privacy: .public)' to '\(newModel.name, privacy: .public)'")
                    chat.imageModel = newModel
                }

                Self.logger.info("\(updateType, privacy: .public) updated successfully")

                // Update the modification timestamp
                let oldTimestamp = chat.updatedAt
                chat.updatedAt = Date()
                Self.logger.debug("Chat timestamp updated from \(oldTimestamp) to \(chat.updatedAt)")

                // Save context
                Self.logger.debug("Saving context changes...")
                try context.save()

                let executionTime = CFAbsoluteTimeGetCurrent() - startTime
                Self.logger.notice("Chat model update completed successfully in \(String(format: "%.3f", executionTime))s")
                Self.logger.info("Update summary - Chat: \(chat.id), \(updateType, privacy: .public): '\(previousModelName, privacy: .public)' -> '\(newModel.name, privacy: .public)'")

                return chat.id
            } catch let error as DatabaseError {
                let executionTime = CFAbsoluteTimeGetCurrent() - startTime
                Self.logger.error("Database error during chat model update after \(String(format: "%.3f", executionTime))s: \(error.localizedDescription)")
                throw error
            } catch {
                let executionTime = CFAbsoluteTimeGetCurrent() - startTime
                Self.logger.error("Unexpected error during chat model update after \(String(format: "%.3f", executionTime))s: \(error.localizedDescription)")
                throw error
            }
        }
    }
}
