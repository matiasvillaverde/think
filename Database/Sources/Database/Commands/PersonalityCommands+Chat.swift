import Foundation
import SwiftData
import OSLog
import Abstractions

// MARK: - Personality-Chat Commands

extension PersonalityCommands {
    /// Gets the chat associated with a personality, creating one if it doesn't exist
    public struct GetChat: WriteCommand {
        public typealias Result = UUID
        public var requiresUser: Bool { true }
        public var requiresRag: Bool { false }

        private let personalityId: UUID

        public init(personalityId: UUID) {
            self.personalityId = personalityId
        }

        public func execute(
            in context: ModelContext,
            userId: PersistentIdentifier?,
            rag: Ragging?
        ) throws -> UUID {
            guard let userId else {
                throw DatabaseError.userNotFound
            }

            let user = try context.getUser(id: userId)

            let descriptor = FetchDescriptor<Personality>(
                predicate: #Predicate<Personality> { $0.id == personalityId }
            )

            guard let personality = try context.fetch(descriptor).first else {
                throw DatabaseError.personalityNotFound
            }

            // If personality already has a chat, return its ID
            if let existingChat = personality.chat {
                Logger.database.info("Returning existing chat \(existingChat.id) for personality \(personalityId)")
                return existingChat.id
            }

            // Create a new chat for this personality
            let chatId = try createChatForPersonality(
                personality: personality,
                user: user,
                context: context
            )

            Logger.database.info("Created new chat \(chatId) for personality \(personalityId)")
            return chatId
        }

        private func createChatForPersonality(
            personality: Personality,
            user: User,
            context: ModelContext
        ) throws -> UUID {
            // Find suitable models from the user's models
            let models = try findModelsForChat(user: user)

            let chat = Chat(
                languageModelConfig: LLMConfiguration.new(personality: personality),
                languageModel: models.language,
                imageModelConfig: DiffusorConfiguration.default,
                imageModel: models.image,
                name: personality.name,
                user: user,
                personality: personality
            )

            context.insert(chat)
            // Note: SwiftData automatically sets personality.chat via the inverse relationship
            try context.save()

            return chat.id
        }

        private func findModelsForChat(user: User) throws -> (language: Model, image: Model) {
            // Priority order for language models
            let languageModelPriority: [SendableModel.ModelType] = [
                .flexibleThinker, .deepLanguage, .visualLanguage, .language
            ]

            var languageModel: Model?
            for modelType in languageModelPriority {
                if let model = user.models.first(where: { $0.type == modelType }) {
                    languageModel = model
                    break
                }
            }

            let imageModel = user.models.first { model in
                switch model.type {
                case .diffusion, .diffusionXL:
                    return true
                default:
                    return false
                }
            }

            guard let langModel = languageModel else {
                Logger.database.error("No language model found for user")
                throw DatabaseError.modelNotFound
            }

            guard let imgModel = imageModel else {
                Logger.database.error("No image model found for user")
                throw DatabaseError.modelNotFound
            }

            return (langModel, imgModel)
        }
    }

    /// Clears all messages from a personality's conversation while keeping the chat
    public struct ClearConversation: WriteCommand {
        public typealias Result = UUID
        public var requiresUser: Bool { false }
        public var requiresRag: Bool { false }

        private let personalityId: UUID

        public init(personalityId: UUID) {
            self.personalityId = personalityId
        }

        public func execute(
            in context: ModelContext,
            userId: PersistentIdentifier?,
            rag: Ragging?
        ) throws -> UUID {
            let descriptor = FetchDescriptor<Personality>(
                predicate: #Predicate<Personality> { $0.id == personalityId }
            )

            guard let personality = try context.fetch(descriptor).first else {
                throw DatabaseError.personalityNotFound
            }

            guard let chat = personality.chat else {
                Logger.database.info("No chat to clear for personality \(personalityId)")
                return personality.id
            }

            // Delete all messages from the chat
            let messageCount = chat.messages.count
            for message in chat.messages {
                context.delete(message)
            }

            // Note: RAG table cleanup would require async context, so it's handled elsewhere
            // The RAG table will be cleaned up on next ingestion or manual cleanup

            try context.save()
            Logger.database.info("Cleared \(messageCount) messages from personality \(personalityId)")

            return personality.id
        }
    }

    /// Creates a chat for a personality if one doesn't exist
    /// This is an internal helper used during personality creation and initialization
    public struct EnsureChat: WriteCommand {
        public typealias Result = UUID
        public var requiresUser: Bool { true }
        public var requiresRag: Bool { false }

        private let personalityId: UUID

        public init(personalityId: UUID) {
            self.personalityId = personalityId
        }

        public func execute(
            in context: ModelContext,
            userId: PersistentIdentifier?,
            rag: Ragging?
        ) throws -> UUID {
            // Delegate to GetChat which handles the creation logic
            try GetChat(personalityId: personalityId).execute(
                in: context,
                userId: userId,
                rag: rag
            )
        }
    }
}
