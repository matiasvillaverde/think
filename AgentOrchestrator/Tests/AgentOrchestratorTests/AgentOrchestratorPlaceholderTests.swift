import Abstractions
import AbstractionsTestUtilities
@testable import AgentOrchestrator
import ContextBuilder
import CoreGraphics
@testable import Database
import Foundation
import Testing
import Tools
#if canImport(AppKit)
import AppKit
#endif

@Suite("AgentOrchestrator Placeholder Image", .tags(.acceptance))
internal struct AgentOrchestratorPlaceholderTests {
    private static let kMegabyte: UInt64 = 1_048_576
    private static let kSlowGenerationDelay: Double = 2.0
    private static let kMaxGenerationTime: TimeInterval = 10.0
    private static let kInitialProgressPercentage: Double = 0.1
    private static let kCompletedProgressPercentage: Double = 1.0

    private struct TestEnvironment {
        let database: Database
        let chatId: UUID
        let orchestrator: AgentOrchestrator
    }

    @Test("Image Generation Always Shows Placeholder Immediately")
    @MainActor
    internal func imageGenerationAlwaysShowsPlaceholder() async throws {
        // This test verifies that a placeholder image is ALWAYS shown immediately
        // when image generation starts. This is critical for UX - users should
        // never see a blank screen while waiting for image generation.

        let testEnv: TestEnvironment = try await setupTestEnvironment()
        let database: Database = testEnv.database
        let chatId: UUID = testEnv.chatId
        let orchestrator: AgentOrchestrator = testEnv.orchestrator

        try await orchestrator.load(chatId: chatId)

        // Start image generation and measure time
        let startTime: TimeInterval = ProcessInfo.processInfo.systemUptime
        try await orchestrator.generate(
            prompt: "A beautiful sunset",
            action: .imageGeneration([])
        )
        let endTime: TimeInterval = ProcessInfo.processInfo.systemUptime

        // Verify placeholder was created immediately
        try await verifyPlaceholderCreatedImmediately(
            database: database,
            chatId: chatId,
            startTime: startTime,
            endTime: endTime
        )
    }

    @MainActor
    private func setupTestEnvironment() async throws -> TestEnvironment {
        let database: Database = try await setupDBWithImageModel()
        let chatId: UUID = try await setupChatWithImageModel(database)
        let imageGenerator: MockImageGenerating = MockImageGenerating()
        await configureSlowImageGeneration(imageGenerator)
        let orchestrator: AgentOrchestrator = createOrchestrator(
            database: database,
            imageGenerator: imageGenerator
        )
        return TestEnvironment(
            database: database,
            chatId: chatId,
            orchestrator: orchestrator
        )
    }

    // MARK: - Helper Methods

    private func createOrchestrator(
        database: Database,
        imageGenerator: MockImageGenerating
    ) -> AgentOrchestrator {
        let coordinator: ModelStateCoordinator = ModelStateCoordinator(
            database: database,
            mlxSession: MockLLMSession(),
            ggufSession: MockLLMSession(),
            imageGenerator: imageGenerator,
            modelDownloader: MockModelDownloader.createConfiguredMock()
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

    private func configureSlowImageGeneration(
        _ imageGenerator: MockImageGenerating
    ) async {
        let stages: [ImageGenerationProgress] = createSlowGenerationStages()
        let response: MockImageGenerating.MockGenerateResponse = MockImageGenerating
            .MockGenerateResponse(
                progress: stages,
                error: nil,
                delayBetweenProgress: Self.kSlowGenerationDelay
            )
        await imageGenerator.configureGenerateResponse(response)
    }

    private func createSlowGenerationStages() -> [ImageGenerationProgress] {
        [
            ImageGenerationProgress(
                stage: .tokenizingPrompt,
                currentImage: nil,
                progressPercentage: Self.kInitialProgressPercentage,
                imageMetrics: nil
            ),
            ImageGenerationProgress(
                stage: .completed,
                currentImage: ImageTestHelpers.createTestCGImage(),
                progressPercentage: Self.kCompletedProgressPercentage,
                imageMetrics: nil
            )
        ]
    }

    @MainActor
    private func verifyPlaceholderCreatedImmediately(
        database: Database,
        chatId: UUID,
        startTime: TimeInterval,
        endTime: TimeInterval
    ) async throws {
        // Verify message was created
        let messageCount: Int = try await database.read(
            MessageCommands.CountMessages(chatId: chatId)
        )
        #expect(messageCount == 1, "Expected one message")

        // Get the message
        let message: Message = try await fetchFirstMessage(database: database, chatId: chatId)

        // Verify placeholder exists
        verifyPlaceholderExists(message: message)

        // Verify timing
        verifyGenerationTiming(startTime: startTime, endTime: endTime)

        // Verify placeholder data validity
        if let imageAttachment = message.responseImage {
            verifyPlaceholderDataValidity(imageData: imageAttachment.image)
        }
    }

    @MainActor
    private func fetchFirstMessage(database: Database, chatId: UUID) async throws -> Message {
        let messages: [Message] = try await database.read(
            MessageCommands.GetAll(chatId: chatId)
        )
        #expect(messages.count == 1, "Expected one message in array")
        return messages[0]
    }

    private func verifyPlaceholderExists(message: Message) {
        #expect(
            message.responseImage != nil,
            "CRITICAL BUG: Response image should exist immediately (placeholder MUST be present)"
        )
    }

    private func verifyGenerationTiming(startTime: TimeInterval, endTime: TimeInterval) {
        let generationTime: TimeInterval = endTime - startTime
        #expect(
            generationTime < Self.kMaxGenerationTime,
            "Generation should complete within 10 seconds, was \(generationTime)s"
        )
    }

    private func verifyPlaceholderDataValidity(imageData: Data) {
        #expect(!imageData.isEmpty, "Placeholder image data should not be empty")
        #expect(
            ImageTestHelpers.createCGImageFromData(imageData) != nil,
            "Placeholder should be valid image data that can create CGImage"
        )
    }
}
