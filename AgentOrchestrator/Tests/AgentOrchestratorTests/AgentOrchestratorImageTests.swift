import Abstractions
import AbstractionsTestUtilities
@testable import AgentOrchestrator
import ContextBuilder
import CoreGraphics
@testable import Database
import Foundation
import Testing
import Tools

@Suite("AgentOrchestrator Image Generation", .tags(.acceptance))
internal struct AgentOrchestratorImageTests {
    @Test("Image Generation Flow with Placeholder Handling")
    @MainActor
    internal func imageGenerationFlowWithPlaceholder() async throws {
        // Setup
        let database: Database = try await setupDBWithImageModel()
        let chatId: UUID = try await setupChatWithImageModel(database)
        let imageGenerator: MockImageGenerating = MockImageGenerating()
        let orchestrator: AgentOrchestrator = createOrchestrator(
            database: database,
            imageGenerator: imageGenerator
        )

        // Configure mock to simulate image generation stages
        await configureImageGeneratorForStages(imageGenerator)

        // Load chat and generate image
        try await orchestrator.load(chatId: chatId)

        // This should trigger the placeholder data bug
        // The system should handle nil placeholder gracefully
        try await orchestrator.generate(
            prompt: "A beautiful sunset",
            action: .imageGeneration([])
        )

        // Verify the image generation completed despite nil placeholder
        try await verifyImageGeneration(database: database, chatId: chatId)
    }

    private func createOrchestrator(
        database: Database,
        imageGenerator: MockImageGenerating
    ) -> AgentOrchestrator {
        let coordinator: ModelStateCoordinator = setupImageCoordinator(
            database: database,
            imageGenerator: imageGenerator
        )
        let persistor: MessagePersistor = MessagePersistor(database: database)
        return AgentOrchestrator(
            modelCoordinator: coordinator,
            persistor: persistor,
            contextBuilder: ContextBuilder(tooling: ToolManager())
        )
    }

    @MainActor
    private func setupDBWithImageModel() async throws -> Database {
        let database: Database = try await ImageTestHelpers.createDatabase()
        let imageModel: ModelDTO = ImageTestHelpers.createImageModelDTO()
        try await database.write(
            ModelCommands.AddModels(modelDTOs: [imageModel])
        )
        return database
    }

    @MainActor
    private func setupChatWithImageModel(_ database: Database) async throws -> UUID {
        // Add language model and create chat
        try await addLanguageModel(database)
        let chatId: UUID = try await createChatWithLanguageModel(database)

        // Set image model for the chat
        try await setImageModelForChat(chatId: chatId, database: database)

        return chatId
    }

    @MainActor
    private func addLanguageModel(_ database: Database) async throws {
        let languageModel: ModelDTO = ImageTestHelpers.createLanguageModelDTO()
        try await database.write(
            ModelCommands.AddModels(modelDTOs: [languageModel])
        )
    }

    @MainActor
    private func createChatWithLanguageModel(_ database: Database) async throws -> UUID {
        let personalityId: UUID = try await database.read(
            PersonalityCommands.GetDefault()
        )

        let models: [SendableModel] = try await database.read(
            ModelCommands.FetchAll()
        )

        guard let langModel = models.first(where: { mdl in
            mdl.modelType == .language
        }) else {
            throw DatabaseError.modelNotFound
        }

        return try await database.write(
            ChatCommands.CreateWithModel(
                modelId: langModel.id,
                personalityId: personalityId
            )
        ) as UUID
    }

    @MainActor
    private func setImageModelForChat(chatId: UUID, database: Database) async throws {
        let models: [SendableModel] = try await database.read(
            ModelCommands.FetchAll()
        )

        guard let imageModel = models.first(where: { mdl in
            mdl.modelType == .diffusion
        }) else {
            throw DatabaseError.modelNotFound
        }

        try await database.write(
            ChatCommands.ModifyChatModelsCommand(
                chatId: chatId,
                newLanguageModelId: nil,
                newImageModelId: imageModel.id
            )
        )
    }

    private func setupImageCoordinator(
        database: Database,
        imageGenerator: MockImageGenerating
    ) -> ModelStateCoordinator {
        ModelStateCoordinator(
            database: database,
            mlxSession: MockLLMSession(),
            ggufSession: MockLLMSession(),
            imageGenerator: imageGenerator,
            modelDownloader: MockModelDownloader.createConfiguredMock()
        )
    }

    private func configureImageGeneratorForStages(
        _ imageGenerator: MockImageGenerating
    ) async {
        let stages: [ImageGenerationProgress] = ImageTestHelpers.createImageGenerationStages()
        let response: MockImageGenerating.MockGenerateResponse = MockImageGenerating
            .MockGenerateResponse(
                progress: stages,
                error: nil,
                delayBetweenProgress: 0.01
            )
        await imageGenerator.configureGenerateResponse(response)
    }

    @MainActor
    private func verifyImageGeneration(
        database: Database,
        chatId: UUID
    ) async throws {
        // Verify message was created
        let messageCount: Int = try await database.read(
            MessageCommands.CountMessages(chatId: chatId)
        )
        #expect(messageCount == 1, "Expected one message to be created")

        // Get the actual message to verify image generation
        let message: Message = try await fetchAndValidateMessage(
            database: database,
            chatId: chatId
        )

        // Verify image was generated
        verifyImageWasGenerated(message: message)

        // Verify image data validity
        if let imageAttachment = message.responseImage {
            verifyImageDataValidity(imageAttachment: imageAttachment)
        }
    }

    @MainActor
    private func fetchAndValidateMessage(
        database: Database,
        chatId: UUID
    ) async throws -> Message {
        let messages: [Message] = try await database.read(
            MessageCommands.GetAll(chatId: chatId)
        )

        guard let message = messages.first else {
            Issue.record("No message found in database")
            throw DatabaseError.messageNotFound
        }

        return message
    }

    private func verifyImageWasGenerated(message: Message) {
        #expect(
            message.responseImage != nil,
            "Response image should exist after generation completes"
        )
    }

    private func verifyImageDataValidity(imageAttachment: ImageAttachment) {
        #expect(!imageAttachment.image.isEmpty, "Image data should not be empty")

        #expect(
            ImageTestHelpers.createCGImageFromData(imageAttachment.image) != nil,
            "Generated image should be valid image data"
        )

        #expect(
            imageAttachment.prompt != nil,
            "Image should have associated prompt"
        )

        #expect(
            imageAttachment.configuration != nil,
            "Image should have configuration from generation"
        )
    }
}
