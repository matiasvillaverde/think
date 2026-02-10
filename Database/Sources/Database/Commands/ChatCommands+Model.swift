import Foundation
import SwiftData
import OSLog
import Abstractions

// MARK: - Chat Model Commands
extension ChatCommands {
    public struct GetLanguageModel: ReadCommand {
        public typealias Result = SendableModel

        private let chatId: UUID

        public init(chatId: UUID) {
            self.chatId = chatId
            Logger.database.info("ChatCommands.GetLanguageModel initialized with chatId: \(chatId)")
        }

        public func execute(
            in context: ModelContext,
            userId: PersistentIdentifier?,
            rag: Ragging?
        ) throws -> SendableModel {
            Logger.database.info("ChatCommands.GetLanguageModel.execute started for chat: \(chatId)")

            let descriptor = FetchDescriptor<Chat>(
                predicate: #Predicate<Chat> { $0.id == chatId }
            )

            Logger.database.info("Fetching chat with id: \(chatId)")
            let chats = try context.fetch(descriptor)

            guard let chat = chats.first else {
                Logger.database.error("ChatCommands.GetLanguageModel.execute failed: chat not found with id: \(chatId)")
                throw DatabaseError.chatNotFound
            }

            let model = chat.languageModel
            Logger.database.info("ChatCommands.GetLanguageModel.execute completed successfully - model: \(model.id)")

            Logger.database.info("ChatCommands.GetLanguageModel.execute completed successfully - model: \(model.id)")
            return model.toSendable()
        }
    }

    public struct GetImageModel: ReadCommand {
        public typealias Result = SendableModel

        private let chatId: UUID

        public init(chatId: UUID) {
            self.chatId = chatId
            Logger.database.info("ChatCommands.GetImageModel initialized with chatId: \(chatId)")
        }

        public func execute(
            in context: ModelContext,
            userId: PersistentIdentifier?,
            rag: Ragging?
        ) throws -> SendableModel {
            Logger.database.info("ChatCommands.GetImageModel.execute started for chat: \(chatId)")

            let descriptor = FetchDescriptor<Chat>(
                predicate: #Predicate<Chat> { $0.id == chatId }
            )

            Logger.database.info("Fetching chat with id: \(chatId)")
            let chats = try context.fetch(descriptor)

            guard let chat = chats.first else {
                Logger.database.error("ChatCommands.GetImageModel.execute failed: chat not found with id: \(chatId)")
                throw DatabaseError.chatNotFound
            }

            let model = chat.imageModel
            Logger.database.info("ChatCommands.GetImageModel.execute completed successfully - model: \(model.id)")

            Logger.database.info("ChatCommands.GetImageModel.execute completed successfully - model: \(model.id)")
            return model.toSendable()
        }
    }

    public struct HaveSameModels: ReadCommand & AnonymousCommand {
        public typealias Result = Bool

        private let chatId1: UUID
        private let chatId2: UUID

        public init(chatId1: UUID, chatId2: UUID) {
            self.chatId1 = chatId1
            self.chatId2 = chatId2
        }

        public func execute(in context: ModelContext) throws -> Bool {
            // AnonymousCommand doesn't need userId or rag
            try execute(in: context, userId: nil, rag: nil)
        }

        public func execute(
            in context: ModelContext,
            userId: PersistentIdentifier?,
            rag: Ragging?
        ) throws -> Bool {
            let chat1 = try ChatCommands.Read(chatId: chatId1).execute(in: context, userId: userId, rag: rag)
            let chat2 = try ChatCommands.Read(chatId: chatId2).execute(in: context, userId: userId, rag: rag)

            let sameLanguageModel = chat1.languageModel.id == chat2.languageModel.id
            let sameImageModel = chat1.imageModel.id == chat2.imageModel.id

            return sameLanguageModel && sameImageModel
        }
    }

    public struct ModifyChatModelsCommand: WriteCommand {
        private let chatId: UUID
        private let newLanguageModelId: UUID?
        private let newImageModelId: UUID?

        public init(chatId: UUID, newLanguageModelId: UUID?, newImageModelId: UUID?) {
            self.chatId = chatId
            self.newLanguageModelId = newLanguageModelId
            self.newImageModelId = newImageModelId
            Logger.database.info("ChatCommands.ModifyChatModelsCommand initialized - chat: \(chatId)")
        }

        public func execute(
            in context: ModelContext,
            userId: PersistentIdentifier?,
            rag: Ragging?
        ) throws -> UUID {
            Logger.database.info("ChatCommands.ModifyChatModelsCommand.execute started")

            let chatDescriptor = FetchDescriptor<Chat>(
                predicate: #Predicate<Chat> { $0.id == chatId }
            )

            guard let chat = try context.fetch(chatDescriptor).first else {
                Logger.database.error("Chat not found with id: \(chatId)")
                throw DatabaseError.chatNotFound
            }

            // Update language model if provided
            if let newLanguageModelId = newLanguageModelId {
                Logger.database.info("Updating language model to: \(newLanguageModelId)")
                let modelDescriptor = FetchDescriptor<Model>(
                    predicate: #Predicate<Model> { $0.id == newLanguageModelId }
                )

                guard let newModel = try context.fetch(modelDescriptor).first else {
                    Logger.database.error("Language model not found with id: \(newLanguageModelId)")
                    throw DatabaseError.modelNotFound
                }

                // For visual language models, update all language-related models
                if newModel.type == .visualLanguage {
                    Logger.database.info("Visual language model detected, updating all language models")
                    chat.languageModel = newModel
                } else {
                    Logger.database.info("Updating language model")
                    chat.languageModel = newModel
                }
            }

            // Update image model if provided
            if let newImageModelId = newImageModelId {
                Logger.database.info("Updating image model to: \(newImageModelId)")
                let modelDescriptor = FetchDescriptor<Model>(
                    predicate: #Predicate<Model> { $0.id == newImageModelId }
                )

                guard let newModel = try context.fetch(modelDescriptor).first else {
                    Logger.database.error("Image model not found with id: \(newImageModelId)")
                    throw DatabaseError.modelNotFound
                }

                chat.imageModel = newModel
            }

            Logger.database.info("Saving context changes")
            try context.save()

            Logger.database.info("ChatCommands.ModifyChatModelsCommand.execute completed successfully")
            return chat.id
        }
    }

    public struct GetLLMConfiguration: ReadCommand {
        public typealias Result = LLMConfiguration

        private let chatId: UUID

        public init(chatId: UUID) {
            self.chatId = chatId
            Logger.database.info("ChatCommands.GetLLMConfiguration initialized with chatId: \(chatId)")
        }

        public func execute(
            in context: ModelContext,
            userId: PersistentIdentifier?,
            rag: Ragging?
        ) throws -> LLMConfiguration {
            Logger.database.info("ChatCommands.GetLLMConfiguration.execute started for chat: \(chatId)")

            let descriptor = FetchDescriptor<Chat>(
                predicate: #Predicate<Chat> { $0.id == chatId }
            )

            guard let chat = try context.fetch(descriptor).first else {
                Logger.database.error("Chat not found with id: \(chatId)")
                throw DatabaseError.chatNotFound
            }

            Logger.database.info("ChatCommands.GetLLMConfiguration.execute completed successfully")
            return chat.languageModelConfig
        }
    }

    public struct GetLanguageModelConfiguration: ReadCommand {
        public typealias Result = SendableLLMConfiguration

        private let chatId: UUID
        private let prompt: String

        public init(chatId: UUID, prompt: String) {
            self.chatId = chatId
            self.prompt = prompt
            Logger.database.info("ChatCommands.GetLanguageModelConfiguration initialized with chatId: \(chatId)")
        }

        public func execute(
            in context: ModelContext,
            userId: PersistentIdentifier?,
            rag: Ragging?
        ) throws -> SendableLLMConfiguration {
            Logger.database.info("ChatCommands.GetLanguageModelConfiguration.execute started for chat: \(chatId)")

            let chat = try ChatCommands.Read(chatId: chatId).execute(in: context, userId: userId, rag: rag)

            // Create configuration based on the chat's personality
            let config = LLMConfiguration.new(personality: chat.personality)

            Logger.database.info("ChatCommands.GetLanguageModelConfiguration.execute completed successfully")
            return config.toSendable(prompt: prompt)
        }
    }

    public struct UpdateLLMConfiguration: WriteCommand {
        public typealias Result = UUID

        private let chatId: UUID
        private let includeCurrentDate: Bool? // swiftlint:disable:this discouraged_optional_boolean
        private let knowledgeCutoffDate: String?
        private let currentDateOverride: String?

        public init(
            chatId: UUID,
            includeCurrentDate: Bool? = nil, // swiftlint:disable:this discouraged_optional_boolean
            knowledgeCutoffDate: String? = nil,
            currentDateOverride: String? = nil
        ) {
            self.chatId = chatId
            self.includeCurrentDate = includeCurrentDate
            self.knowledgeCutoffDate = knowledgeCutoffDate
            self.currentDateOverride = currentDateOverride
            Logger.database.info("ChatCommands.UpdateLLMConfiguration initialized for chat: \(chatId)")
        }

        public func execute(
            in context: ModelContext,
            userId: PersistentIdentifier?,
            rag: Ragging?
        ) throws -> UUID {
            Logger.database.info("ChatCommands.UpdateLLMConfiguration.execute started")

            let chat = try ChatCommands.Read(chatId: chatId).execute(in: context, userId: userId, rag: rag)

            // Update the LLM configuration fields
            if let includeCurrentDate = includeCurrentDate {
                chat.languageModelConfig.includeCurrentDate = includeCurrentDate
            }
            if let knowledgeCutoffDate = knowledgeCutoffDate {
                chat.languageModelConfig.knowledgeCutoffDate = knowledgeCutoffDate
            }
            if let currentDateOverride = currentDateOverride {
                chat.languageModelConfig.currentDateOverride = currentDateOverride
            }

            try context.save()
            Logger.database.info("ChatCommands.UpdateLLMConfiguration.execute completed")
            return chatId
        }
    }

    // MARK: - Fallback Model Commands

    /// Gets the fallback model IDs for a chat
    public struct GetFallbackModels: ReadCommand {
        public typealias Result = [UUID]

        private let chatId: UUID

        public init(chatId: UUID) {
            self.chatId = chatId
            Logger.database.info("ChatCommands.GetFallbackModels initialized for chat: \(chatId)")
        }

        public func execute(
            in context: ModelContext,
            userId: PersistentIdentifier?,
            rag: Ragging?
        ) throws -> [UUID] {
            Logger.database.info("ChatCommands.GetFallbackModels.execute started")

            let chat = try ChatCommands.Read(chatId: chatId)
                .execute(in: context, userId: userId, rag: rag)

            Logger.database.info(
                "ChatCommands.GetFallbackModels.execute completed - \(chat.fallbackModelIds.count) models"
            )
            return chat.fallbackModelIds
        }
    }

    /// Sets the fallback model IDs for a chat
    public struct SetFallbackModels: WriteCommand {
        public typealias Result = UUID

        private let chatId: UUID
        private let fallbackModelIds: [UUID]

        public init(chatId: UUID, fallbackModelIds: [UUID]) {
            self.chatId = chatId
            self.fallbackModelIds = fallbackModelIds
            Logger.database.info(
                "ChatCommands.SetFallbackModels initialized for chat: \(chatId)"
            )
        }

        public func execute(
            in context: ModelContext,
            userId: PersistentIdentifier?,
            rag: Ragging?
        ) throws -> UUID {
            Logger.database.info("ChatCommands.SetFallbackModels.execute started")

            let chat = try ChatCommands.Read(chatId: chatId)
                .execute(in: context, userId: userId, rag: rag)

            chat.fallbackModelIds = fallbackModelIds
            try context.save()

            Logger.database.info("ChatCommands.SetFallbackModels.execute completed")
            return chatId
        }
    }

    /// Adds a model to the fallback chain
    public struct AddFallbackModel: WriteCommand {
        public typealias Result = UUID

        private let chatId: UUID
        private let modelId: UUID

        public init(chatId: UUID, modelId: UUID) {
            self.chatId = chatId
            self.modelId = modelId
            Logger.database.info(
                "ChatCommands.AddFallbackModel initialized for chat: \(chatId) model: \(modelId)"
            )
        }

        public func execute(
            in context: ModelContext,
            userId: PersistentIdentifier?,
            rag: Ragging?
        ) throws -> UUID {
            Logger.database.info("ChatCommands.AddFallbackModel.execute started")

            let chat = try ChatCommands.Read(chatId: chatId)
                .execute(in: context, userId: userId, rag: rag)

            // Avoid duplicates
            if !chat.fallbackModelIds.contains(modelId) {
                chat.fallbackModelIds.append(modelId)
            }
            try context.save()

            Logger.database.info("ChatCommands.AddFallbackModel.execute completed")
            return chatId
        }
    }

    /// Removes a model from the fallback chain
    public struct RemoveFallbackModel: WriteCommand {
        public typealias Result = UUID

        private let chatId: UUID
        private let modelId: UUID

        public init(chatId: UUID, modelId: UUID) {
            self.chatId = chatId
            self.modelId = modelId
            Logger.database.info(
                "ChatCommands.RemoveFallbackModel initialized for chat: \(chatId)"
            )
        }

        public func execute(
            in context: ModelContext,
            userId: PersistentIdentifier?,
            rag: Ragging?
        ) throws -> UUID {
            Logger.database.info("ChatCommands.RemoveFallbackModel.execute started")

            let chat = try ChatCommands.Read(chatId: chatId)
                .execute(in: context, userId: userId, rag: rag)

            chat.fallbackModelIds.removeAll { $0 == modelId }
            try context.save()

            Logger.database.info("ChatCommands.RemoveFallbackModel.execute completed")
            return chatId
        }
    }
}
