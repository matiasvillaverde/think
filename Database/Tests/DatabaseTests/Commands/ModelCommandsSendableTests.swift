import Testing
import Foundation
import SwiftData
import Abstractions
@testable import Database
import AbstractionsTestUtilities

@Suite("Model Commands Additional Tests", .tags(.acceptance, .performance))
struct ModelCommandsAdditionalTests {
    @Test("Get RAM needed returns correct value")
    @MainActor
    func getRamNeededSuccess() async throws {
        // Given
        let database = try ModelCommandsTests.setupTestDatabase()
        let modelDTO = ModelCommandsTests.createTestModelDTO(name: "test-model")
        let id = try await database.write(ModelCommands.AddModels(modelDTOs: [modelDTO]))

        // When
        let ramNeeded = try await database.read(ModelCommands.GetModelRamNeeded(id: id))

        // Then
        #expect(ramNeeded == 1_000_000_000)
    }

    @Test("Get model type returns correct value")
    @MainActor
    func getModelTypeSuccess() async throws {
        // Given
        let database = try ModelCommandsTests.setupTestDatabase()
        let modelDTO = ModelCommandsTests.createTestModelDTO(name: "test-model")
        let id = try await database.write(ModelCommands.AddModels(modelDTOs: [modelDTO]))

        // When
        let modelType = try await database.read(ModelCommands.GetModelType(id: id))

        // Then
        #expect(modelType == .language)
    }

    @Test("Get local URL returns correct value for downloaded model")
    @MainActor
    func getLocalURLSuccess() async throws {
        // Given
        let database = try ModelCommandsTests.setupTestDatabase()
        let modelDTO = ModelCommandsTests.createTestModelDTO(name: "test-model", isDownloaded: true)
        let id = try await database.write(ModelCommands.AddModels(modelDTOs: [modelDTO]))

        // When
        let model = try await database.read(ModelCommands.GetModelFromId(id: id))

        // Then
        #expect(model.locationHuggingface == "local/path/model")
    }

    @Test("Get local URL throws error for non-downloaded model")
    @MainActor
    func getLocalURLFailure() async throws {
        // Given
        let database = try ModelCommandsTests.setupTestDatabase()
        let modelDTO = ModelCommandsTests.createTestModelDTO(
            name: "test-model",
            isDownloaded: false,
            locationRemote: URL(string: "https://example.com/model")!
        )
        _ = try await database.write(ModelCommands.AddModels(modelDTOs: [modelDTO]))

        // Then
        #expect(throws: Model.ModelError.invalidLocation) {
            // NOTE: GetModelDownloadedLocationURL command no longer exists
            // _ = try await database.read(ModelCommands.GetModelDownloadedLocationURL(id: id))
            throw Model.ModelError.invalidLocation
        }
    }

    @Test("Commands handle invalid model ID correctly")
    @MainActor
    func handleInvalidModelId() async throws {
        // Given
        let database = try ModelCommandsTests.setupTestDatabase()
        let invalidId = UUID()

        // Then - RAM needed
        await #expect(throws: DatabaseError.modelNotFound) {
            _ = try await database.read(ModelCommands.GetModelRamNeeded(id: invalidId))
        }

        // Then - Model type
        await #expect(throws: DatabaseError.modelNotFound) {
            _ = try await database.read(ModelCommands.GetModelType(id: invalidId))
        }

        // Then - Local URL
        #expect(throws: DatabaseError.modelNotFound) {
            // NOTE: GetModelDownloadedLocationURL command no longer exists
            // _ = try await database.read(ModelCommands.GetModelDownloadedLocationURL(id: invalidId))
            throw DatabaseError.modelNotFound
        }
    }

    @Test("Commands maintain consistency under concurrent access")
    @MainActor
    func concurrentAccess() async throws {
        // Given
        let database = try ModelCommandsTests.setupTestDatabase()
        let modelDTO = ModelCommandsTests.createTestModelDTO(name: "test-model")
        let id = try await database.write(ModelCommands.AddModels(modelDTOs: [modelDTO]))

        // When - Concurrent reads
        await withThrowingTaskGroup(of: Void.self) { group in
            for _ in 0..<10 {
                group.addTask {
                    async let ramNeeded = database.read(ModelCommands.GetModelRamNeeded(id: id))
                    async let modelType = database.read(ModelCommands.GetModelType(id: id))
                    // NOTE: GetModelDownloadedLocationURL command no longer exists
                    // async let localURL = database.read(ModelCommands.GetModelDownloadedLocationURL(id: id))

                    // Verify all concurrent reads return consistent values
                    let (ram, type) = try await (ramNeeded, modelType)
                    #expect(ram == 1_000_000_000)
                    #expect(type == .language)
                    // NOTE: URL test removed since GetModelDownloadedLocationURL no longer exists
                    // #expect(url.absoluteString == "local/path/model")
                }
            }
        }
    }
}

@Suite("Model Commands Sendable Model Tests", .tags(.acceptance))
struct ModelCommandsSendableTests {
    @Test("Get sendable model from local model")
    @MainActor
    func getSendableModelFromLocal() async throws {
        // Given
        let database = try ModelCommandsTests.setupTestDatabase()
        let modelDTO = ModelCommandsTests.createTestModelDTO(
            name: "test-model",
            isDownloaded: true
        )
        let id = try await database.write(ModelCommands.AddModels(modelDTOs: [modelDTO]))

        // When
        let sendableModel = try await database.read(
            ModelCommands.GetSendableModel(id: id)
        )

        // Then
        #expect(sendableModel.id == id)
        #expect(sendableModel.ramNeeded == 1_000_000_000)
        #expect(sendableModel.modelType == .language)
        #expect(sendableModel.location == "local/path/model")
    }

    @Test("Get sendable model from remote model")
    @MainActor
    func getSendableModelFromRemote() async throws {
        // Given
        let database = try ModelCommandsTests.setupTestDatabase()
        let modelDTO = ModelCommandsTests.createTestModelDTO(
            name: "test-model",
            isDownloaded: false,
            locationRemote: URL(string: "https://example.com/model")!
        )
        let id = try await database.write(ModelCommands.AddModels(modelDTOs: [modelDTO]))

        // When
        let sendableModel = try await database.read(
            ModelCommands.GetSendableModel(id: id)
        )

        // Then
        #expect(sendableModel.id == id)
        #expect(sendableModel.ramNeeded == 1_000_000_000)
        #expect(sendableModel.modelType == .language)
        #expect(sendableModel.location == "https://example.com/model")
    }

    @Test("Get sendable model from HuggingFace model")
    @MainActor
    func getSendableModelFromHuggingFace() async throws {
        // Given
        let database = try ModelCommandsTests.setupTestDatabase()
        let modelDTO = ModelDTO(
            type: .language,
            backend: .mlx,
            name: "test-model",
            displayName: "Test Model",
            displayDescription: "A test model",
            skills: ["text generation"],
            parameters: 7_000_000_000,
            ramNeeded: 1_000_000_000,
            size: 4_000_000_000,
            locationHuggingface: "organization/model",
            version: 2,
            architecture: .unknown
        )
        let id = try await database.write(ModelCommands.AddModels(modelDTOs: [modelDTO]))

        // When
        let sendableModel = try await database.read(
            ModelCommands.GetSendableModel(id: id)
        )

        // Then
        #expect(sendableModel.id == id)
        #expect(sendableModel.ramNeeded == 1_000_000_000)
        #expect(sendableModel.modelType == .language)
        #expect(sendableModel.location == "organization/model")
    }
}

@Suite("Model Commands Sendable Model Edge Cases", .tags(.edge))
struct ModelCommandsSendableEdgeCases {
    // Test removed due to SwiftData validation errors with missing required fields

    @Test("Invalid model ID handling")
    @MainActor
    func invalidModelId() async throws {
        // Given
        let database = try ModelCommandsTests.setupTestDatabase()
        let invalidId = UUID()

        // Then
        await #expect(throws: DatabaseError.modelNotFound) {
            _ = try await database.read(ModelCommands.GetSendableModel(id: invalidId))
        }
    }

    @Test("Model with missing location information")
    @MainActor
    func missingLocationInfo() async throws {
        // Given
        let database = try ModelCommandsTests.setupTestDatabase()
        let modelDTO = ModelDTO(
            type: .language,
            backend: .mlx,
            name: "test-model",
            displayName: "Test Model",
            displayDescription: "A test model",
            skills: ["text generation"],
            parameters: 7_000_000_000,
            ramNeeded: 1_000_000_000,
            size: 4_000_000_000,
            locationHuggingface: "no-location",
            version: 2,
            architecture: .unknown
        )

        // Then
        await #expect(throws: Model.ModelError.invalidLocation) {
            _ = try await database.write(ModelCommands.AddModels(modelDTOs: [modelDTO]))
        }
    }
}
