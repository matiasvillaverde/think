import Foundation
import SwiftData
import OSLog
import Abstractions
import DataAssets

// MARK: - Chat Creation Commands
extension ChatCommands {
    public struct Create: WriteCommand {
        private let personalityId: UUID

        public init(personality: UUID) {
            self.personalityId = personality
            Logger.database.info("ChatCommands.Create initialized with personalityId: \(personality.uuidString)")
        }

        public func execute(
            in context: ModelContext,
            userId: PersistentIdentifier?,
            rag: Ragging?
        ) throws -> UUID {
            Logger.database.info("ChatCommands.Create.execute started")

            guard let userId else {
                Logger.database.error("ChatCommands.Create.execute failed: user not found")
                throw DatabaseError.userNotFound
            }

            Logger.database.info("Fetching user with id: \(userId.id.hashValue)")
            let user = try context.getUser(id: userId)
            Logger.database.info("Successfully fetched user: \(user.id)")

            Logger.database.info("Finding models from last chat or using defaults")
            let models = try self.findModelsForNewChat(for: user)
            Logger.database.info("Successfully found models - language: \(models.language.id), image: \(models.imageGeneration.id)")

            let descriptor = FetchDescriptor<Personality>(
                predicate: #Predicate<Personality> { $0.id == personalityId }
            )

            Logger.database.info("Fetching personality with id: \(personalityId.uuidString)")
            let personality: Personality
            if let existingDefault = try context.fetch(descriptor).first {
                Logger.database.info("Found existing personality: \(existingDefault.id)")
                personality = existingDefault
            } else {
                Logger.database.info("No existing personality found, creating safe default personality")
                // SAFE: Use factory method to get or create default personality
                do {
                    personality = try PersonalityFactory.getOrCreateSystemPersonality(
                        systemInstruction: .englishAssistant,
                        in: context
                    )
                    Logger.database.info("Created/found default personality with id: \(personality.id)")
                } catch {
                    Logger.database.error("Failed to get/create default personality: \(error)")
                    throw DatabaseError.personalityNotFound
                }
            }

            Logger.database.info("Creating new chat with models and personality")
            let chat = Chat(
                languageModelConfig: LLMConfiguration.new(personality: personality),
                languageModel: models.language,
                imageModelConfig: DiffusorConfiguration.default,
                imageModel: models.imageGeneration,
                name: "New Chat",
                user: user,
                personality: personality
            )
            context.insert(chat)

            // Chats are automatically added through the relationship
            Logger.database.info("Chat will be added to user through relationship")

            Logger.database.info("Saving context changes")
            try context.save()

            Logger.database.info("ChatCommands.Create.execute completed successfully - chat id: \(chat.id)")
            return chat.id
        }

        // MARK: - Helper Methods

        private func findModelsForNewChat(for user: User) throws -> RequiredModels {
            Logger.database.info("Finding models for new chat")

            // Try to use models from the last chat first
            if let lastChat = user.chats.last {
                Logger.database.info("Using models from last chat: language=\(lastChat.languageModel.id), image=\(lastChat.imageModel.id)")
                return RequiredModels(
                    language: lastChat.languageModel,
                    imageGeneration: lastChat.imageModel
                )
            }

            // Fallback: If no previous chats, use priority-based selection for best user experience
            Logger.database.info("No previous chats found, using priority-based fallback selection")

            let availableModels = user.models
            Logger.database.info("Found \(availableModels.count) available models")
            
            // Priority order for language models (best capability first)
            let languageModelPriority: [SendableModel.ModelType] = [.flexibleThinker, .deepLanguage, .visualLanguage, .language]
            
            // Find best language model by priority
            var languageModel: Model?
            for modelType in languageModelPriority {
                if let model = availableModels.first(where: { $0.type == modelType }) {
                    languageModel = model
                    Logger.database.info("Selected language model by priority: \(model.name)")
                    break
                }
            }

            // Find any image generation model (no priority needed)
            let imageModel = availableModels.first { model in
                switch model.type {
                case .diffusion, .diffusionXL:
                    return true
                default:
                    return false
                }
            }

            guard let langModel = languageModel else {
                Logger.database.error("No language model found")
                throw DatabaseError.modelNotFound
            }

            guard let imgModel = imageModel else {
                Logger.database.error("No image generation model found")
                throw DatabaseError.modelNotFound
            }

            Logger.database.info("Successfully found fallback models")
            return RequiredModels(
                language: langModel,
                imageGeneration: imgModel
            )
        }

        private struct RequiredModels {
            let language: Model
            let imageGeneration: Model
        }
    }

    public struct CreateWithModel: WriteCommand {
        private let personalityId: UUID
        private let modelId: UUID

        public init(modelId: UUID, personalityId: UUID) {
            self.personalityId = personalityId
            self.modelId = modelId
            Logger.database.info("ChatCommands.CreateWithModel initialized - modelId: \(modelId.uuidString), personalityId: \(personalityId.uuidString)")
        }

        public func execute(
            in context: ModelContext,
            userId: PersistentIdentifier?,
            rag: Ragging?
        ) throws -> UUID {
            Logger.database.info("ChatCommands.CreateWithModel.execute started")

            guard let userId else {
                Logger.database.error("ChatCommands.CreateWithModel.execute failed: user not found")
                throw DatabaseError.userNotFound
            }

            Logger.database.info("Fetching user with id: \(userId.id.hashValue)")
            let user = try context.getUser(id: userId)
            Logger.database.info("Successfully fetched user: \(user.id)")

            // Find the specified model
            let modelDescriptor = FetchDescriptor<Model>(
                predicate: #Predicate<Model> { $0.id == modelId }
            )

            guard let specifiedModel = try context.fetch(modelDescriptor).first else {
                Logger.database.error("Specified model not found: \(modelId)")
                throw DatabaseError.modelNotFound
            }

            Logger.database.info("Found specified model: \(specifiedModel.displayName)")

            // Determine models based on the specified model's type
            let languageModel: Model
            let imageModel: Model

            switch specifiedModel.type {
            case .language, .visualLanguage, .deepLanguage, .flexibleThinker:
                // Use specified model as language model, find compatible image model
                languageModel = specifiedModel
                guard let foundImageModel = user.models.first(where: { model in
                    switch model.type {
                    case .diffusion, .diffusionXL:
                        return true
                    default:
                        return false
                    }
                }) else {
                    Logger.database.error("No compatible image model found")
                    throw DatabaseError.modelNotFound
                }
                imageModel = foundImageModel
            case .diffusion, .diffusionXL:
                // Use specified model as image model, find compatible language model
                imageModel = specifiedModel
                guard let foundLanguageModel = user.models.first(where: {
                    switch $0.type {
                    case .language, .visualLanguage, .deepLanguage, .flexibleThinker:
                        return true
                    default:
                        return false
                    }
                }) else {
                    Logger.database.error("No compatible language model found")
                    throw DatabaseError.modelNotFound
                }
                languageModel = foundLanguageModel
            }

            // Find or create personality
            let personalityDescriptor = FetchDescriptor<Personality>(
                predicate: #Predicate<Personality> { $0.id == personalityId }
            )

            Logger.database.info("Fetching personality with id: \(personalityId.uuidString)")
            let personality: Personality
            if let existingPersonality = try context.fetch(personalityDescriptor).first {
                Logger.database.info("Found existing personality: \(existingPersonality.id)")
                personality = existingPersonality
            } else {
                Logger.database.info("No existing personality found, creating safe default personality")
                // SAFE: Use factory method to get or create default personality
                do {
                    personality = try PersonalityFactory.getOrCreateSystemPersonality(
                        systemInstruction: .englishAssistant,
                        in: context
                    )
                    Logger.database.info("Created/found default personality with id: \(personality.id)")
                } catch {
                    Logger.database.error("Failed to get/create default personality: \(error)")
                    throw DatabaseError.personalityNotFound
                }
            }

            Logger.database.info("Creating new chat with specified models")
            let chat = Chat(
                languageModelConfig: LLMConfiguration.new(personality: personality),
                languageModel: languageModel,
                imageModelConfig: DiffusorConfiguration.default,
                imageModel: imageModel,
                name: "New Chat",
                user: user,
                personality: personality
            )
            context.insert(chat)

            // Chats are automatically added through the relationship
            Logger.database.info("Chat will be added to user through relationship")

            Logger.database.info("Saving context changes")
            try context.save()

            Logger.database.info("ChatCommands.CreateWithModel.execute completed successfully - chat id: \(chat.id)")
            return chat.id
        }
    }

    public struct ResetAllChats: WriteCommand {
        private let systemInstruction: SystemInstruction

        public init(systemInstruction: SystemInstruction) {
            self.systemInstruction = systemInstruction
            Logger.database.info("ChatCommands.ResetAllChats initialized")
        }

        public func execute(
            in context: ModelContext,
            userId: PersistentIdentifier?,
            rag: Ragging?
        ) throws -> UUID {
            Logger.database.info("ChatCommands.ResetAllChats.execute started")

            guard let userId else {
                Logger.database.error("ChatCommands.ResetAllChats.execute failed: user not found")
                throw DatabaseError.userNotFound
            }

            Logger.database.info("Fetching user with id: \(userId.id.hashValue)")
            let user = try context.getUser(id: userId)
            Logger.database.info("Successfully fetched user: \(user.id)")

            // Check if we have required models before deleting chats
            let downloadedModels = user.models
            let hasLanguageModel = downloadedModels.contains(where: { model in
                switch model.type {
                case .language, .visualLanguage, .deepLanguage, .flexibleThinker:
                    return true
                default:
                    return false
                }
            })
            let hasImageModel = downloadedModels.contains(where: { model in
                switch model.type {
                case .diffusion, .diffusionXL:
                    return true
                default:
                    return false
                }
            })

            guard hasLanguageModel, hasImageModel else {
                Logger.database.error("ResetAllChats failed: Missing required models - language: \(hasLanguageModel), image: \(hasImageModel)")
                throw DatabaseError.invalidInput("Cannot reset chats without both language and image models available")
            }

            Logger.database.info("Deleting all existing chats (count: \(user.chats.count))")

            // Delete all existing chats
            for chat in user.chats {
                Logger.database.debug("Deleting chat: \(chat.id)")
                context.delete(chat)
            }

            // Delete all chats - they are removed through the relationship

            Logger.database.info("Saving context after chat deletion")
            try context.save()

            // Create a new default chat
            Logger.database.info("Creating new default chat")
            // Create a new default chat with the provided systemInstruction
            let personalityId = Personality.default.id  // Using default personality for now
            let chatId = try Create(personality: personalityId).execute(
                in: context,
                userId: userId,
                rag: rag
            )

            Logger.database.info("ChatCommands.ResetAllChats.execute completed successfully - new chat id: \(chatId)")
            return chatId
        }
    }
}
