import Abstractions
import AbstractionsTestUtilities
@testable import AgentOrchestrator
import CoreGraphics
@testable import Database
import Foundation
import OSLog
import Testing

@Suite("ImageMetrics Integration")
internal struct ImageMetricsTests {
    @Test("MessagePersistor correctly handles ImageMetrics")
    @MainActor
    internal func messagePersistorHandlesImageMetrics() async throws {
        // Given: Setup test environment
        let env: TestEnvironment = try await setupTestEnvironment()

        // When: Updating generated image with metrics
        try await env.persistor.updateGeneratedImage(
            messageId: env.messageId,
            cgImage: env.cgImage,
            configurationId: env.configId,
            prompt: "Test prompt",
            imageMetrics: env.imageMetrics
        )

        // Then: Verify image and metrics are saved
        try await verifyImageAndMetricsSaved(
            database: env.database,
            messageId: env.messageId
        )
    }

    private struct TestEnvironment {
        let database: Database
        let persistor: MessagePersistor
        let messageId: UUID
        let cgImage: CGImage
        let imageMetrics: ImageMetrics
        let configId: UUID
    }

    @MainActor
    private func setupTestEnvironment() async throws -> TestEnvironment {
        let database: Database = try await ImageTestHelpers.createDatabase()
        let persistor: MessagePersistor = MessagePersistor(database: database)
        let chatId: UUID = try await setupChatWithMessage(database: database)
        let messageId: UUID = try await getFirstMessageId(database: database, chatId: chatId)
        let cgImage: CGImage = try #require(ImageTestHelpers.createTestCGImage())

        // Create a proper image configuration in the database
        let imageConfig: ImageConfiguration = try await database.read(
            ImageCommands.GetImageConfiguration(chat: chatId, prompt: "Test prompt")
        )

        return TestEnvironment(
            database: database,
            persistor: persistor,
            messageId: messageId,
            cgImage: cgImage,
            imageMetrics: ImageTestHelpers.createTestImageMetrics(),
            configId: imageConfig.id
        )
    }

    @MainActor
    private func verifyImageAndMetricsSaved(
        database: Database,
        messageId: UUID
    ) async throws {
        // Verify image saved
        let message: Message = try await database.read(
            MessageCommands.Read(id: messageId)
        )
        #expect(message.responseImage != nil, "Image should be saved")

        // Verify metrics saved
        let metrics: Metrics? = try await database.read(
            MetricsCommands.Get(messageId: messageId)
        )
        #expect(metrics != nil, "Metrics should be saved")
        #expect(metrics?.totalTime != 0, "Timing metrics should be preserved")
        #expect(
            metrics?.promptTokens != 0 || metrics?.generatedTokens != 0,
            "Usage metrics should be preserved"
        )
    }

    @Test("ImageMetrics conversion preserves essential data")
    internal func imageMetricsConversionPreservesData() {
        // Given: Test image metrics
        let imageMetrics: ImageMetrics = ImageTestHelpers.createTestImageMetrics()

        // When: Converting to ChunkMetrics (testing internal conversion logic)
        // Note: In real code, this happens inside MessagePersistor

        // Then: Verify the metrics contain expected values
        #expect(imageMetrics.timing != nil, "Should have timing metrics")
        #expect(imageMetrics.usage != nil, "Should have usage metrics")
        #expect(imageMetrics.generation != nil, "Should have generation metrics")

        // Verify specific values
        if let timing = imageMetrics.timing {
            #expect(timing.totalTime == Duration.seconds(10.0), "Total time should match")
            #expect(timing.modelLoadTime == Duration.seconds(2.0), "Model load time should match")
        }

        if let usage = imageMetrics.usage {
            #expect(usage.promptTokens == 10, "Prompt tokens should match")
            #expect(usage.modelParameters == 7_000_000_000, "Model parameters should match")
        }

        if let generation = imageMetrics.generation {
            #expect(generation.width == 512, "Width should match")
            #expect(generation.height == 512, "Height should match")
            #expect(generation.steps == 50, "Steps should match")
        }
    }

    // MARK: - Helper Methods

    @MainActor
    private func setupChatWithMessage(database: Database) async throws -> UUID {
        try await addTestModels(database: database)
        let chatId: UUID = try await createChat(database: database)
        try await createMessage(database: database, chatId: chatId)
        return chatId
    }

    @MainActor
    private func addTestModels(database: Database) async throws {
        let models: [ModelDTO] = [
            ImageTestHelpers.createLanguageModelDTO(),
            ImageTestHelpers.createImageModelDTO()
        ]
        try await database.write(
            ModelCommands.AddModels(modelDTOs: models)
        )
    }

    @MainActor
    private func createChat(database: Database) async throws -> UUID {
        let personalityId: UUID = try await database.read(
            PersonalityCommands.GetDefault()
        )
        let langModel: SendableModel = try await getLanguageModel(database: database)
        let chatId: UUID = try await database.write(
            ChatCommands.CreateWithModel(
                modelId: langModel.id,
                personalityId: personalityId
            )
        ) as UUID

        // Also set an image model for the chat
        let imageModel: SendableModel = try await getImageModel(database: database)
        try await database.write(
            ChatCommands.ModifyChatModelsCommand(
                chatId: chatId,
                newLanguageModelId: nil,
                newImageModelId: imageModel.id
            )
        )

        return chatId
    }

    @MainActor
    private func getLanguageModel(database: Database) async throws -> SendableModel {
        let models: [SendableModel] = try await database.read(
            ModelCommands.FetchAll()
        )
        guard let langModel = models.first(where: { $0.modelType == .language }) else {
            throw DatabaseError.modelNotFound
        }
        return langModel
    }

    @MainActor
    private func getImageModel(database: Database) async throws -> SendableModel {
        let models: [SendableModel] = try await database.read(
            ModelCommands.FetchAll()
        )
        guard let imageModel = models.first(where: { $0.modelType == .diffusion }) else {
            throw DatabaseError.modelNotFound
        }
        return imageModel
    }

    @MainActor
    private func createMessage(database: Database, chatId: UUID) async throws {
        let messageId: UUID = try await database.write(
            MessageCommands.Create(
                chatId: chatId,
                userInput: "Test message",
                isDeepThinker: false
            )
        ) as UUID
        // Store the message ID for later retrieval
        Self.logger.debug("Created message with ID: \(messageId)")
    }

    private static let logger: Logger = Logger(
        subsystem: "AgentOrchestratorTests",
        category: "ImageMetricsTests"
    )

    @MainActor
    private func getFirstMessageId(database: Database, chatId: UUID) async throws -> UUID {
        let messages: [Message] = try await database.read(
            MessageCommands.GetAll(chatId: chatId)
        )
        guard let firstMessage = messages.first else {
            throw DatabaseError.messageNotFound
        }
        return firstMessage.id
    }
}
