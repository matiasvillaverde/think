import Testing
import Foundation
import SwiftData
@testable import Database
import AbstractionsTestUtilities
import Abstractions

@Suite("App Initialization - Existing User Scenario", .serialized)
struct AppInitializationExistingUserTests {
    @Test("Creates initial chat when user has v2 models but no chats")
    @MainActor
    func existingUserWithV2ModelsButNoChatsCreatesInitialChat() async throws {
        // Given - Database with user having v2 models but no chats
        let mockRag = MockRagging()
        let config = DatabaseConfiguration(
            isStoredInMemoryOnly: true,
            allowsSave: true,
            ragFactory: MockRagFactory(mockRag: mockRag)
        )
        let database = try Database.new(configuration: config)

        // Create user with v2 models
        let user = User()
        let v2LanguageModel = try ModelDTO(
            type: .language,
            backend: .mlx,
            name: "v2-language-model",
            displayName: "V2 Language Model",
            displayDescription: "A v2 language model",
            skills: ["text-generation"],
            parameters: 1_000_000_000,
            ramNeeded: 2.gigabytes,
            size: 1.gigabytes,
            locationHuggingface: "mlx-community/v2-model",
            version: 2,
            architecture: .unknown
        ).createModel()

        let v2ImageModel = try ModelDTO(
            type: .diffusion,
            backend: .coreml,
            name: "v2-image-model",
            displayName: "V2 Image Model",
            displayDescription: "A v2 image model",
            skills: ["image-generation"],
            parameters: 500_000_000,
            ramNeeded: 3.gigabytes,
            size: 2.gigabytes,
            locationHuggingface: "coreml-community/v2-image",
            version: 2,
            architecture: .unknown
        ).createModel()

        // Add default personality
        let personality = PersonalityFactory.createSystemPersonalities().first { $0.isDefault }!

        database.modelContainer.mainContext.insert(user)
        database.modelContainer.mainContext.insert(v2LanguageModel)
        database.modelContainer.mainContext.insert(v2ImageModel)
        database.modelContainer.mainContext.insert(personality)
        user.models.append(v2LanguageModel)
        user.models.append(v2ImageModel)
        try database.modelContainer.mainContext.save()

        // When - Initialize app for existing user
        let result = try await database.execute(AppCommands.Initialize())

        // Then - Initial chat should be created with v2 models
        #expect(user.chats.count == 1)

        let chat = user.chats.first!
        #expect(chat.languageModel.version == 2)
        #expect(chat.imageModel.version == 2)
        #expect(chat.languageModel.id == v2LanguageModel.id)
        #expect(chat.imageModel.id == v2ImageModel.id)

        // Verify existing user with new chat returns chat screen
        #expect(result.targetScreen == .chat)
    }

        @Test("Adds image model when existing user has v2 language only")
    @MainActor
    func existingUserWithLanguageOnlyAddsImageModel() async throws {
        // Given - Database with user having v2 language model only
        let mockRag = MockRagging()
        let config = DatabaseConfiguration(
            isStoredInMemoryOnly: true,
            allowsSave: true,
            ragFactory: MockRagFactory(mockRag: mockRag)
        )
        let database = try Database.new(configuration: config)

        let user = User()
        let v2LanguageModel = try ModelDTO(
            type: .language,
            backend: .mlx,
            name: "v2-language-model",
            displayName: "V2 Language Model",
            displayDescription: "A v2 language model",
            skills: ["text-generation"],
            parameters: 1_000_000_000,
            ramNeeded: 2.gigabytes,
            size: 1.gigabytes,
            locationHuggingface: "mlx-community/v2-model",
            version: 2,
            architecture: .unknown
        ).createModel()

        database.modelContainer.mainContext.insert(user)
        database.modelContainer.mainContext.insert(v2LanguageModel)
        user.models.append(v2LanguageModel)
        try database.modelContainer.mainContext.save()

        // When - Initialize app for existing user
        let result = try await database.execute(AppCommands.Initialize())

        // Then - Image model should be added and chat created
        let imageModels = user.models.filter { model in
            (model.type == .diffusion || model.type == .diffusionXL) && model.version == 2
        }
        #expect(imageModels.count == 1)
        #expect(user.chats.count == 1)
        #expect(user.chats.first?.imageModel.id == imageModels.first?.id)
        #expect(result.targetScreen == .chat)
    }

@Test("Reuses existing chat when user has chat with messages (1:1 relationship)")
    @MainActor
    func existingUserWithNonEmptyChatReusesExisting() async throws {
        // Given - Database with user having v2 models and existing chat with messages
        let mockRag = MockRagging()
        let config = DatabaseConfiguration(
            isStoredInMemoryOnly: true,
            allowsSave: true,
            ragFactory: MockRagFactory(mockRag: mockRag)
        )
        let database = try Database.new(configuration: config)

        // Create user with v2 models and existing chat
        let user = User()
        let v2LanguageModel = try ModelDTO(
            type: .language,
            backend: .mlx,
            name: "v2-language-model",
            displayName: "V2 Language Model",
            displayDescription: "A v2 language model",
            skills: ["text-generation"],
            parameters: 1_000_000_000,
            ramNeeded: 2.gigabytes,
            size: 1.gigabytes,
            locationHuggingface: "mlx-community/v2-model",
            version: 2,
            architecture: .unknown
        ).createModel()

        let v2ImageModel = try ModelDTO(
            type: .diffusion,
            backend: .coreml,
            name: "v2-image-model",
            displayName: "V2 Image Model",
            displayDescription: "A v2 image model",
            skills: ["image-generation"],
            parameters: 500_000_000,
            ramNeeded: 3.gigabytes,
            size: 2.gigabytes,
            locationHuggingface: "coreml-community/v2-image",
            version: 2,
            architecture: .unknown
        ).createModel()

        let personality = PersonalityFactory.createSystemPersonalities().first { $0.isDefault }!

        // Create existing chat with multiple messages
        let existingChat = Chat(
            languageModelConfig: .default,
            languageModel: v2LanguageModel,
            imageModelConfig: .default,
            imageModel: v2ImageModel,
            user: user,
            personality: personality
        )

        // Add messages to make it non-empty
        let message1 = Message(
            userInput: "Hello",
            chat: existingChat,
            languageModelConfiguration: .default,
            languageModel: v2LanguageModel,
            imageModel: v2ImageModel,
            metrics: Metrics()
        )
        let message2 = Message(
            userInput: "Hello!",
            chat: existingChat,
            languageModelConfiguration: .default,
            languageModel: v2LanguageModel,
            imageModel: v2ImageModel,
            metrics: Metrics()
        )

        // Add channel to message2
        let finalChannel = Channel(type: .final, content: "Hi there!", order: 0)
        finalChannel.message = message2
        message2.channels = [finalChannel]

        database.modelContainer.mainContext.insert(user)
        database.modelContainer.mainContext.insert(v2LanguageModel)
        database.modelContainer.mainContext.insert(v2ImageModel)
        database.modelContainer.mainContext.insert(personality)
        database.modelContainer.mainContext.insert(existingChat)
        database.modelContainer.mainContext.insert(message1)
        database.modelContainer.mainContext.insert(message2)
        user.models.append(v2LanguageModel)
        user.models.append(v2ImageModel)
        try database.modelContainer.mainContext.save()

        // When - Initialize app for existing user
        let result = try await database.execute(AppCommands.Initialize())

        // Then - In the 1:1 architecture, existing chat is reused (only 1 chat per personality)
        #expect(user.chats.count == 1)

        // Verify the existing chat is preserved with v2 models
        let theChat = user.chats.first!
        #expect(theChat.languageModel.version == 2)
        #expect(theChat.imageModel.version == 2)

        // Verify existing user with existing chats returns chat screen
        #expect(result.targetScreen == .chat)
    }
    
    @Test("Does NOT create launch chat when last chat is empty")
    @MainActor
    func existingUserWithEmptyChatDoesNotCreateLaunchChat() async throws {
        // Given - Database with user having v2 models and existing empty chat
        let mockRag = MockRagging()
        let config = DatabaseConfiguration(
            isStoredInMemoryOnly: true,
            allowsSave: true,
            ragFactory: MockRagFactory(mockRag: mockRag)
        )
        let database = try Database.new(configuration: config)

        // Create user with v2 models and existing chat
        let user = User()
        let v2LanguageModel = try ModelDTO(
            type: .language,
            backend: .mlx,
            name: "v2-language-model",
            displayName: "V2 Language Model",
            displayDescription: "A v2 language model",
            skills: ["text-generation"],
            parameters: 1_000_000_000,
            ramNeeded: 2.gigabytes,
            size: 1.gigabytes,
            locationHuggingface: "mlx-community/v2-model",
            version: 2,
            architecture: .unknown
        ).createModel()

        let v2ImageModel = try ModelDTO(
            type: .diffusion,
            backend: .coreml,
            name: "v2-image-model",
            displayName: "V2 Image Model",
            displayDescription: "A v2 image model",
            skills: ["image-generation"],
            parameters: 500_000_000,
            ramNeeded: 3.gigabytes,
            size: 2.gigabytes,
            locationHuggingface: "coreml-community/v2-image",
            version: 2,
            architecture: .unknown
        ).createModel()

        let personality = PersonalityFactory.createSystemPersonalities().first { $0.isDefault }!

        // Create existing chat with NO messages (empty chat)
        let existingChat = Chat(
            languageModelConfig: .default,
            languageModel: v2LanguageModel,
            imageModelConfig: .default,
            imageModel: v2ImageModel,
            user: user,
            personality: personality
        )

        database.modelContainer.mainContext.insert(user)
        database.modelContainer.mainContext.insert(v2LanguageModel)
        database.modelContainer.mainContext.insert(v2ImageModel)
        database.modelContainer.mainContext.insert(personality)
        database.modelContainer.mainContext.insert(existingChat)
        user.models.append(v2LanguageModel)
        user.models.append(v2ImageModel)
        try database.modelContainer.mainContext.save()

        // When - Initialize app for existing user
        let result = try await database.execute(AppCommands.Initialize())

        // Then - NO new launch chat should be created (still 1 chat)
        #expect(user.chats.count == 1)

        // Verify existing user with existing chats returns chat screen
        #expect(result.targetScreen == .chat)
    }
    
    @Test("Does NOT create launch chat when last chat has only one message")
    @MainActor
    func existingUserWithSingleMessageChatDoesNotCreateLaunchChat() async throws {
        // Given - Database with user having v2 models and existing chat with only 1 message
        let mockRag = MockRagging()
        let config = DatabaseConfiguration(
            isStoredInMemoryOnly: true,
            allowsSave: true,
            ragFactory: MockRagFactory(mockRag: mockRag)
        )
        let database = try Database.new(configuration: config)

        // Create user with v2 models and existing chat
        let user = User()
        let v2LanguageModel = try ModelDTO(
            type: .language,
            backend: .mlx,
            name: "v2-language-model",
            displayName: "V2 Language Model",
            displayDescription: "A v2 language model",
            skills: ["text-generation"],
            parameters: 1_000_000_000,
            ramNeeded: 2.gigabytes,
            size: 1.gigabytes,
            locationHuggingface: "mlx-community/v2-model",
            version: 2,
            architecture: .unknown
        ).createModel()

        let v2ImageModel = try ModelDTO(
            type: .diffusion,
            backend: .coreml,
            name: "v2-image-model",
            displayName: "V2 Image Model",
            displayDescription: "A v2 image model",
            skills: ["image-generation"],
            parameters: 500_000_000,
            ramNeeded: 3.gigabytes,
            size: 2.gigabytes,
            locationHuggingface: "coreml-community/v2-image",
            version: 2,
            architecture: .unknown
        ).createModel()

        let personality = PersonalityFactory.createSystemPersonalities().first { $0.isDefault }!

        // Create existing chat with only ONE message
        let existingChat = Chat(
            languageModelConfig: .default,
            languageModel: v2LanguageModel,
            imageModelConfig: .default,
            imageModel: v2ImageModel,
            user: user,
            personality: personality
        )
        
        // Add only ONE message
        let message1 = Message(
            userInput: "Hello",
            chat: existingChat,
            languageModelConfiguration: .default,
            languageModel: v2LanguageModel,
            imageModel: v2ImageModel,
            metrics: Metrics()
        )

        database.modelContainer.mainContext.insert(user)
        database.modelContainer.mainContext.insert(v2LanguageModel)
        database.modelContainer.mainContext.insert(v2ImageModel)
        database.modelContainer.mainContext.insert(personality)
        database.modelContainer.mainContext.insert(existingChat)
        database.modelContainer.mainContext.insert(message1)
        user.models.append(v2LanguageModel)
        user.models.append(v2ImageModel)
        try database.modelContainer.mainContext.save()

        // When - Initialize app for existing user
        let result = try await database.execute(AppCommands.Initialize())

        // Then - NO new launch chat should be created (still 1 chat)
        #expect(user.chats.count == 1)

        // Verify existing user with existing chats returns chat screen
        #expect(result.targetScreen == .chat)
    }

    @Test("Does not create chat when user has no v2 language model")
    @MainActor
    func existingUserWithoutV2LanguageModelDoesNotCreateChat() async throws {
        // Given - Database with user having only v2 image model
        let mockRag = MockRagging()
        let config = DatabaseConfiguration(
            isStoredInMemoryOnly: true,
            allowsSave: true,
            ragFactory: MockRagFactory(mockRag: mockRag)
        )
        let database = try Database.new(configuration: config)

        // Create user with only v2 image model
        let user = User()
        let v2ImageModel = try ModelDTO(
            type: .diffusion,
            backend: .coreml,
            name: "v2-image-model",
            displayName: "V2 Image Model",
            displayDescription: "A v2 image model",
            skills: ["image-generation"],
            parameters: 500_000_000,
            ramNeeded: 3.gigabytes,
            size: 2.gigabytes,
            locationHuggingface: "coreml-community/v2-image",
            version: 2,
            architecture: .unknown
        ).createModel()

        database.modelContainer.mainContext.insert(user)
        database.modelContainer.mainContext.insert(v2ImageModel)
        user.models.append(v2ImageModel)
        try database.modelContainer.mainContext.save()

        // When - Initialize app for existing user
        let result = try await database.execute(AppCommands.Initialize())

        // Then - No chats should be created
        #expect(user.chats.isEmpty)

        // Should show welcome screen (no v2 language model)
        let hasV2Language = user.models.contains { $0.type == .language && $0.version == 2 }
        #expect(!hasV2Language)

        // Verify existing user without v2 language model returns welcome screen
        #expect(result.targetScreen == .welcome)
    }

    @Test("Does not modify existing models")
    @MainActor
    func existingUserDoesNotModifyExistingModels() async throws {
        // Given - Database with user having v2 models
        let mockRag = MockRagging()
        let config = DatabaseConfiguration(
            isStoredInMemoryOnly: true,
            allowsSave: true,
            ragFactory: MockRagFactory(mockRag: mockRag)
        )
        let database = try Database.new(configuration: config)

        // Create user with v2 models
        let user = User()
        let v2LanguageModel = try ModelDTO(
            type: .language,
            backend: .mlx,
            name: "existing-v2-language",
            displayName: "Existing V2 Language",
            displayDescription: "An existing v2 model",
            skills: ["text-generation"],
            parameters: 1_000_000_000,
            ramNeeded: 2.gigabytes,
            size: 1.gigabytes,
            locationHuggingface: "mlx-community/existing-v2",
            version: 2,
            architecture: .unknown
        ).createModel()

        let v2ImageModel = try ModelDTO(
            type: .diffusion,
            backend: .coreml,
            name: "existing-v2-image",
            displayName: "Existing V2 Image",
            displayDescription: "An existing v2 image model",
            skills: ["image-generation"],
            parameters: 500_000_000,
            ramNeeded: 3.gigabytes,
            size: 2.gigabytes,
            locationHuggingface: "coreml-community/existing-v2-image",
            version: 2,
            architecture: .unknown
        ).createModel()

        database.modelContainer.mainContext.insert(user)
        database.modelContainer.mainContext.insert(v2LanguageModel)
        database.modelContainer.mainContext.insert(v2ImageModel)
        user.models.append(v2LanguageModel)
        user.models.append(v2ImageModel)
        try database.modelContainer.mainContext.save()

        let initialModelCount = user.models.count

        // When - Initialize app for existing user
        _ = try await database.execute(AppCommands.Initialize())

        // Then - No additional models should be created
        #expect(user.models.count == initialModelCount)
        #expect(v2LanguageModel.name == "existing-v2-language")
        #expect(v2ImageModel.name == "existing-v2-image")
        #expect(v2LanguageModel.version == 2)
        #expect(v2ImageModel.version == 2)
    }

    @Test("FlexibleThinker models are recognized as language-capable for chat creation")
    @MainActor
    func flexibleThinkerModelsRecognizedAsLanguageCapableForChatCreation() async throws {
        // This test proves the bug fix: downloaded flexibleThinker models (like Qwen)
        // should be recognized as language-capable and allow chat creation

        // Given - Database with user having a downloaded v2 flexibleThinker model
        let mockRag = MockRagging()
        let config = DatabaseConfiguration(
            isStoredInMemoryOnly: true,
            allowsSave: true,
            ragFactory: MockRagFactory(mockRag: mockRag)
        )
        let database = try Database.new(configuration: config)

        // Create user with downloaded flexibleThinker model (simulating CreateFromDiscovery)
        let user = User()
        let downloadedFlexibleThinker = try ModelDTO(
            type: .flexibleThinker,
            backend: .mlx,
            name: "Qwen3-0.6B-4bit",
            displayName: "Qwen3-0.6B-4bit",
            displayDescription: "Downloaded Qwen model",
            skills: ["text-generation"],
            parameters: 600_000_000,
            ramNeeded: 1.gigabytes,
            size: 351_386_061,
            locationHuggingface: "mlx-community/Qwen3-1.7B-4bit",
            version: 2, // This is the fix - downloaded models now get version 2
            architecture: .qwen
        ).createModel()
        downloadedFlexibleThinker.state = .downloaded

        let v2ImageModel = try ModelDTO(
            type: .diffusion,
            backend: .coreml,
            name: "stable-diffusion-v2",
            displayName: "Stable Diffusion v2",
            displayDescription: "V2 image generation model",
            skills: ["image-generation"],
            parameters: 500_000_000,
            ramNeeded: 3.gigabytes,
            size: 2.gigabytes,
            locationHuggingface: "coreml-community/stable-diffusion-v2",
            version: 2,
            architecture: .unknown
        ).createModel()

        let personality = PersonalityFactory.createSystemPersonalities().first { $0.isDefault }!

        database.modelContainer.mainContext.insert(user)
        database.modelContainer.mainContext.insert(downloadedFlexibleThinker)
        database.modelContainer.mainContext.insert(v2ImageModel)
        database.modelContainer.mainContext.insert(personality)
        user.models.append(downloadedFlexibleThinker)
        user.models.append(v2ImageModel)
        try database.modelContainer.mainContext.save()

        // When - Initialize app (simulating app restart after download + chat creation)
        let result = try await database.execute(AppCommands.Initialize())

        // Then - FlexibleThinker should be recognized as language-capable
        let hasV2LanguageCapable = user.models.contains {
            ($0.type == .language || $0.type == .deepLanguage || $0.type == .flexibleThinker) && $0.version == 2
        }
        #expect(hasV2LanguageCapable == true)

        // Chat should be created with the flexibleThinker model
        #expect(user.chats.count == 1)
        let chat = user.chats.first!
        #expect(chat.languageModel.type == .flexibleThinker)
        #expect(chat.languageModel.version == 2)
        #expect(chat.languageModel.id == downloadedFlexibleThinker.id)

        // App should route to chat screen, not welcome screen
        #expect(result.targetScreen == .chat)
    }
}
