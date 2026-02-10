import Foundation
import SwiftData
import OSLog
import Abstractions
import DataAssets

// MARK: - Model Type Helpers

private extension SendableModel.ModelType {
    var isLanguageCapable: Bool {
        switch self {
        case .language, .visualLanguage, .deepLanguage, .flexibleThinker:
            return true
        default:
            return false
        }
    }

    var isImageCapable: Bool {
        switch self {
        case .diffusion, .diffusionXL:
            return true
        default:
            return false
        }
    }
}

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
                do {
                    personality = try getOrCreateDefaultPersonality(in: context)
                    Logger.database.info("Created/found default personality with id: \(personality.id)")
                } catch {
                    Logger.database.error("Failed to get/create default personality: \(error)")
                    throw DatabaseError.personalityNotFound
                }
            }

            // Check if personality already has a chat (1:1 relationship)
            if let existingChat = personality.chat {
                Logger.database.info("Personality already has chat \(existingChat.id), clearing messages")
                // Clear existing messages but keep the chat
                for message in existingChat.messages {
                    context.delete(message)
                }
                try context.save()
                return existingChat.id
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

        private func getOrCreateDefaultPersonality(in context: ModelContext) throws -> Personality {
            let descriptor = FetchDescriptor<Personality>(
                predicate: #Predicate<Personality> { $0.isDefault == true }
            )
            if let existing = try context.fetch(descriptor).first {
                return existing
            }

            let created = Personality(
                systemInstruction: .empatheticFriend,
                name: "Buddy",
                description: "A good buddy: upbeat, loyal, and real with you",
                imageName: "friend-icon",
                category: .personal,
                isDefault: true
            )
            context.insert(created)
            return created
        }

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

            // If the user has no image models yet, seed a sensible default so chat creation
            // never hard-fails (the user can download/configure later).
            guard let imgModel = imageModel ?? seedDefaultImageModelIfNeeded(for: user, availableModels: availableModels) else {
                Logger.database.error("No image generation model found and default seeding failed")
                throw DatabaseError.modelNotFound
            }

            Logger.database.info("Successfully found fallback models")
            return RequiredModels(
                language: langModel,
                imageGeneration: imgModel
            )
        }

        private func seedDefaultImageModelIfNeeded(for user: User, availableModels: [Model]) -> Model? {
            _ = user
            // If an image model exists, don't create anything.
            if let existing = availableModels.first(where: { $0.type.isImageCapable }) {
                return existing
            }

            // Use DataAssets recommended defaults as a stable seed.
            guard let imagesRepoId: String = RecommendedModels.defaultImageModels.first else {
                return nil
            }

            let modelType: SendableModel.ModelType = inferImageModelType(from: imagesRepoId)

            do {
                // Minimal model entry; download happens later via ModelDownloader.
                let seeded = try Model(
                    type: modelType,
                    backend: .coreml,
                    name: imagesRepoId,
                    displayName: "Image Generator",
                    displayDescription: "Recommended image model (download to enable image generation).",
                    author: "coreml-community",
                    license: nil,
                    licenseUrl: nil,
                    tags: ["image", "recommended"],
                    downloads: 0,
                    likes: 0,
                    lastModified: nil,
                    skills: [],
                    parameters: 1,
                    ramNeeded: 1,
                    size: 1,
                    locationHuggingface: imagesRepoId,
                    locationKind: .huggingFace,
                    locationLocal: nil,
                    locationBookmark: nil,
                    version: 2,
                    architecture: .stableDiffusion
                )

                // SwiftData: append to relationship so it shows up for the user.
                if user.models.isEmpty {
                    user.models = [seeded]
                } else {
                    user.models.append(seeded)
                }
                return seeded
            } catch {
                Logger.database.error("Failed seeding default image model: \(error.localizedDescription)")
                return nil
            }
        }

        private func inferImageModelType(from location: String) -> SendableModel.ModelType {
            let lowercased = location.lowercased()
            if lowercased.contains("sdxl") || lowercased.contains("xl") {
                return .diffusionXL
            }
            return .diffusion
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
            let specifiedModel = try fetchSpecifiedModel(in: context)
            let models = try resolveModels(specifiedModel: specifiedModel, user: user)
            let personality = try fetchOrCreatePersonality(in: context)

            // Handle existing chat (1:1 relationship)
            if let existingChat = personality.chat {
                return try updateExistingChat(existingChat, models: models, context: context)
            }

            return try createNewChat(
                personality: personality,
                models: models,
                user: user,
                context: context
            )
        }

        private func fetchSpecifiedModel(in context: ModelContext) throws -> Model {
            let modelDescriptor = FetchDescriptor<Model>(
                predicate: #Predicate<Model> { $0.id == modelId }
            )

            guard let model = try context.fetch(modelDescriptor).first else {
                throw DatabaseError.modelNotFound
            }
            return model
        }

        private func resolveModels(
            specifiedModel: Model,
            user: User
        ) throws -> (language: Model, image: Model) {
            if specifiedModel.type.isLanguageCapable {
                let imageModel = try findImageModel(in: user.models)
                return (specifiedModel, imageModel)
            } else {
                let languageModel = try findLanguageModel(in: user.models)
                return (languageModel, specifiedModel)
            }
        }

        private func findImageModel(in models: [Model]) throws -> Model {
            guard let model = models.first(where: { $0.type.isImageCapable }) else {
                throw DatabaseError.modelNotFound
            }
            return model
        }

        private func findLanguageModel(in models: [Model]) throws -> Model {
            guard let model = models.first(where: { $0.type.isLanguageCapable }) else {
                throw DatabaseError.modelNotFound
            }
            return model
        }

        private func fetchOrCreatePersonality(in context: ModelContext) throws -> Personality {
            let descriptor = FetchDescriptor<Personality>(
                predicate: #Predicate<Personality> { $0.id == personalityId }
            )

            if let existing = try context.fetch(descriptor).first {
                return existing
            }

            // Fall back to default personality rather than creating an unsupported system personality.
            let defaultDescriptor = FetchDescriptor<Personality>(
                predicate: #Predicate<Personality> { $0.isDefault == true }
            )
            if let existingDefault = try context.fetch(defaultDescriptor).first {
                return existingDefault
            }

            let created = Personality(
                systemInstruction: .empatheticFriend,
                name: "Buddy",
                description: "A good buddy: upbeat, loyal, and real with you",
                imageName: "friend-icon",
                category: .personal,
                isDefault: true
            )
            context.insert(created)
            return created
        }

        private func updateExistingChat(
            _ chat: Chat,
            models: (language: Model, image: Model),
            context: ModelContext
        ) throws -> UUID {
            for message in chat.messages {
                context.delete(message)
            }
            chat.languageModel = models.language
            chat.imageModel = models.image
            try context.save()
            return chat.id
        }

        private func createNewChat(
            personality: Personality,
            models: (language: Model, image: Model),
            user: User,
            context: ModelContext
        ) throws -> UUID {
            let chat = Chat(
                languageModelConfig: LLMConfiguration.new(personality: personality),
                languageModel: models.language,
                imageModelConfig: DiffusorConfiguration.default,
                imageModel: models.image,
                name: "New Chat",
                user: user,
                personality: personality
            )
            context.insert(chat)
            try context.save()
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
            let personality: Personality
            do {
                personality = try PersonalityFactory.getOrCreateSystemPersonality(
                    systemInstruction: systemInstruction,
                    in: context
                )
            } catch {
                // Be resilient: if a requested instruction isn't supported as a system personality,
                // fall back to whatever the app considers the default.
                let descriptor = FetchDescriptor<Personality>(
                    predicate: #Predicate<Personality> { $0.isDefault == true }
                )
                if let existingDefault = try context.fetch(descriptor).first {
                    personality = existingDefault
                } else {
                    let created = Personality(
                        systemInstruction: .empatheticFriend,
                        name: "Buddy",
                        description: "A good buddy: upbeat, loyal, and real with you",
                        imageName: "friend-icon",
                        category: .personal,
                        isDefault: true
                    )
                    context.insert(created)
                    personality = created
                }
            }

            let chatId = try Create(personality: personality.id).execute(
                in: context,
                userId: userId,
                rag: rag
            )

            Logger.database.info("ChatCommands.ResetAllChats.execute completed successfully - new chat id: \(chatId)")
            return chatId
        }
    }
}
