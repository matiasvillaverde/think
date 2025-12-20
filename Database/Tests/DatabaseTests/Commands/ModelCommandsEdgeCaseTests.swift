import Testing
import Foundation
import SwiftData
@testable import Database
import AbstractionsTestUtilities

@Suite("Model Commands Edge Case Tests", .tags(.edge))
struct ModelCommandsEdgeCaseTests {
    @Test("Can delete non-downloaded model")
    @MainActor
    func canDeleteNonDownloaded() async throws {
        // Given
        let database = try await ModelCommandsTests.setupTestDatabase()
        let modelDTO = ModelCommandsTests.createTestModelDTO(
            name: "test-model",
            isDownloaded: false,
            locationRemote: URL(string: "https://example.com/model")!
        )
        let id = try await database.write(ModelCommands.AddModels(models: [modelDTO]))

        // When - Delete model location (now allowed from any state)
        let result = try await database.write(ModelCommands.DeleteModelLocation(
            model: id
        ))

        // Then - Should succeed and return the model ID
        #expect(result == id)

        // Verify model state changed to notDownloaded
        let state = try await database.read(ModelCommands.GetModelState(id: id))
        #expect(state == .notDownloaded)
    }

    @Test("Model with empty displayName uses name as fallback")
    @MainActor
    func emptyDisplayNameFallback() async throws {
        // Given - Create a model DTO with empty displayName
        let database = try await ModelCommandsTests.setupTestDatabase()
        let modelDTO = ModelDTO(
            type: .language,
            backend: .mlx,
            name: "test-model-name",
            displayName: "", // Empty displayName
            displayDescription: "A test model",
            skills: ["text generation"],
            parameters: 7_000_000_000,
            ramNeeded: 1_000_000_000,
            size: 4_000_000_000,
            locationHuggingface: "organization/model",
            version: 2,
            architecture: .unknown
        )

        // When
        let id = try await database.write(ModelCommands.AddModels(models: [modelDTO]))
        let model = try await database.read(ModelCommands.GetModelFromId(id: id))

        // Then - displayName should fallback to name
        #expect(model.displayName == "test-model-name")
        #expect(model.name == "test-model-name")
    }

    @Test("Automatic migration handles models with default values")
    @MainActor
    func automaticMigrationWithDefaultValues() async throws {
        // This test verifies that SwiftData's automatic migration works correctly
        // when properties have default values

        // Given - Create a database and add a model
        let database = try await ModelCommandsTests.setupTestDatabase()
        let modelDTO = ModelCommandsTests.createTestModelDTO(
            name: "test-migration-model",
            isDownloaded: false,
            locationRemote: URL(string: "https://example.com/model")!
        )

        let modelId = try await database.write(
            ModelCommands.AddModels(models: [modelDTO])
        )

        // Verify model was created correctly
        let model = try await database.read(
            ModelCommands.GetModelFromId(id: modelId)
        )
        #expect(model.displayName == "Test Model") // From createTestModelDTO
        #expect(model.name == "test-migration-model")
        #expect(model.state == .notDownloaded)

        // When - Simulate operations that would occur after migration
        // First start the download
        try await database.write(
            ModelCommands.UpdateModelDownloadProgress(
                id: modelId,
                progress: 0.5
            )
        )

        // Complete the download
        try await database.write(
            ModelCommands.UpdateModelDownloadProgress(
                id: modelId,
                progress: 1.0
            )
        )

        // Then - Verify that the model can be fetched and has correct state
        let updatedModel = try await database.read(
            ModelCommands.GetModelFromId(id: modelId)
        )
        #expect(updatedModel.state == .downloaded)
        #expect(updatedModel.displayName == "Test Model")

        // Test edge case: Create model with empty displayName to verify fallback works
        let emptyDisplayNameDTO = ModelDTO(
            type: .language,
            backend: .mlx,
            name: "fallback-test",
            displayName: "",
            displayDescription: "Test fallback",
            skills: ["text generation"],
            parameters: 1_000_000,
            ramNeeded: 100_000,
            size: 200_000,
            locationHuggingface: "test/fallback-model",
            version: 2,
            architecture: .unknown
        )

        // Add the second model
        try await database.write(
            ModelCommands.AddModels(models: [emptyDisplayNameDTO])
        )

        // Retrieve the model by name since AddModels returns the first model's ID
        let fallbackModel = try await database.read(
            ModelCommands.GetModel(name: "fallback-test")
        )

        // Verify fallback behavior - when displayName is empty, it should use name
        #expect(fallbackModel.displayName == fallbackModel.name)
        #expect(fallbackModel.name == "fallback-test")
    }
}

@Suite("Model Commands Additional Edge Cases", .tags(.edge, .regression))
struct ModelCommandsAdditionalEdgeCases {
    @Test("Memory requirements validation")
    @MainActor
    func memoryRequirementsValidation() async throws {
        // Given
        let database = try await ModelCommandsTests.setupTestDatabase()
        _ = ModelCommandsTests.createTestModelDTO(
            name: "huge-model",
            isDownloaded: false,
            locationRemote: URL(string: "https://example.com/huge-model")
        )

        // When - Try to add a model with RAM requirements exceeding system memory
        let hugeModelDTO = ModelDTO(
            type: .language,
            backend: .mlx,
            name: "huge-model",
            displayName: "Huge Model",
            displayDescription: "A model requiring too much RAM",
            skills: ["text generation"],
            parameters: 7_000_000_000,
            ramNeeded: ProcessInfo.processInfo.physicalMemory + 1,  // Exceeds available RAM
            size: 4_000_000_000,
            locationHuggingface: "https://example.com/huge-model",
            version: 2,
            architecture: .unknown
        )

        try await database.write(ModelCommands.AddModels(models: [hugeModelDTO]))

        // Then - Model should not be added
        let descriptor = FetchDescriptor<Model>()
        let models = try database.modelContainer.mainContext.fetch(descriptor)
        #expect(models.isEmpty)
    }

    @Test("Empty model list handling")
    @MainActor
    func emptyModelListHandling() async throws {
        // Given
        let database = try await ModelCommandsTests.setupTestDatabase()

        // When/Then - Adding empty model list should not crash
        try await database.write(ModelCommands.AddModels(models: []))

        // Verify system state
        let descriptor = FetchDescriptor<Model>()
        let models = try database.modelContainer.mainContext.fetch(descriptor)
        #expect(models.isEmpty)
    }

    @Test("Multiple delete attempts maintain consistency")
    @MainActor
    func multipleDeleteAttempts() async throws {
        // Given
        let database = try await ModelCommandsTests.setupTestDatabase()
        let modelDTO = ModelCommandsTests.createTestModelDTO(
            name: "test-model",
            isDownloaded: true
        )
        let id = try await database.write(ModelCommands.AddModels(models: [modelDTO]))

        let model = try await database.read(ModelCommands.GetModelFromId(id: id))

        // When - Delete multiple times (now allowed from any state)
        let firstResult = try await database.write(ModelCommands.DeleteModelLocation(
            model: id
        ))
        #expect(firstResult == id)

        // Then - Second delete should also succeed (idempotent operation)
        let secondResult = try await database.write(ModelCommands.DeleteModelLocation(
            model: id
        ))
        #expect(secondResult == id)

        // Verify final state is still notDownloaded
        let finalState = try await database.read(ModelCommands.GetModelState(id: id))
        #expect(finalState == .notDownloaded)
    }
}
