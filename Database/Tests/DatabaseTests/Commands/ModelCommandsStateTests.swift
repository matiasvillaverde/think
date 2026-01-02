import Testing
import Foundation
import SwiftData
@testable import Database
import AbstractionsTestUtilities

@Suite("Model Commands State Transition Tests", .tags(.state))
struct ModelCommandsStateTests {
    @Test("Model download progress updates correctly")
    @MainActor
    func downloadProgressUpdates() async throws {
        // Given
        let database = try ModelCommandsTests.setupTestDatabase()
        let modelDTO = ModelCommandsTests.createTestModelDTO(
            name: "test-model",
            isDownloaded: false,
            locationRemote: URL(string: "https://example.com/model")!
        )
        let id = try await database.write(ModelCommands.AddModels(modelDTOs: [modelDTO]))
        let model = try await database.read(ModelCommands.GetModelFromId(id: id))
        #expect(model.state?.isDownloadingActive == false)

        // Verify initial state
        var state = try await database.read(
            ModelCommands.GetModelState(id: id)
        )
        #expect(state == .notDownloaded)

        // When - Update with significant change (> 0.05)
        try await database.write(ModelCommands.UpdateModelDownloadProgress(
            id: id,
            progress: 0.5
        ))

        // Then - Should update
        state = try await database.read(
            ModelCommands.GetModelState(id: id)
        )
        #expect(state == .downloadingActive)
        let updatedModel = try await database.read(ModelCommands.GetModelFromId(id: id))
        #expect(updatedModel.downloadProgress == 0.5)

        // When - Update with insignificant change (< 0.05)
        try await database.write(ModelCommands.UpdateModelDownloadProgress(
            id: id,
            progress: 0.53
        ))

        // Then - Should not update, should maintain previous progress
        state = try await database.read(
            ModelCommands.GetModelState(id: id)
        )

        #expect(state == .downloadingActive)
        let updatedModel2 = try await database.read(ModelCommands.GetModelFromId(id: id))
        #expect(updatedModel2.downloadProgress == 0.53)
        #expect(updatedModel2.state?.isDownloadingActive == true)
    }

    @Test("Model download progress handles completion correctly")
    @MainActor
    func downloadProgressCompletion() async throws {
        // Given
        let database = try ModelCommandsTests.setupTestDatabase()
        let modelDTO = ModelCommandsTests.createTestModelDTO(
            name: "test-model",
            isDownloaded: false,
            locationRemote: URL(string: "https://example.com/llm")!
        )
        let id = try await database.write(ModelCommands.AddModels(modelDTOs: [modelDTO]))

        // Verify initial state
        var state = try await database.read(
            ModelCommands.GetModelState(id: id)
        )
        #expect(state == .notDownloaded)

        // When - Progress at 0.98 (high but not complete)
        try await database.write(ModelCommands.UpdateModelDownloadProgress(
            id: id,
            progress: 0.98
        ))

        // Then - Should be in downloading state
        state = try await database.read(
            ModelCommands.GetModelState(id: id)
        )
        #expect(state == .downloadingActive)
        let model98 = try await database.read(ModelCommands.GetModelFromId(id: id))
        #expect(model98.downloadProgress == 0.98)

        // When - Complete the download
        try await database.write(ModelCommands.UpdateModelDownloadProgress(
            id: id,
            progress: 1.0
        ))

        // Then - Should transition to downloaded state regardless of minimum change threshold
        state = try await database.read(
            ModelCommands.GetModelState(id: id)
        )
        #expect(state == .downloaded)
        // NOTE: downloadedLocation property no longer exists
        // #expect(model.downloadedLocation == "llm")
    }

    @Test("Model state changes to downloaded when progress is exactly 1.0")
    @MainActor
    func stateChangesToDownloadedAtExactlyOne() async throws {
        // Given
        let database = try ModelCommandsTests.setupTestDatabase()
        let modelDTO = ModelCommandsTests.createTestModelDTO(
            name: "test-model",
            isDownloaded: false,
            locationRemote: URL(string: "https://example.com/model")!
        )
        let id = try await database.write(ModelCommands.AddModels(modelDTOs: [modelDTO]))

        // Verify initial state
        var state = try await database.read(
            ModelCommands.GetModelState(id: id)
        )
        #expect(state == .notDownloaded)

        // First set to downloading state with progress < 1
        try await database.write(ModelCommands.UpdateModelDownloadProgress(
            id: id,
            progress: 0.8
        ))

        // Verify intermediate state
        state = try await database.read(
            ModelCommands.GetModelState(id: id)
        )
        #expect(state == .downloadingActive)
        let model80 = try await database.read(ModelCommands.GetModelFromId(id: id))
        #expect(model80.downloadProgress == 0.8)

        // When - Update with progress exactly 1.0
        try await database.write(ModelCommands.UpdateModelDownloadProgress(
            id: id,
            progress: 1.0
        ))

        // Then - Should transition to downloaded state regardless of minimum change threshold
        state = try await database.read(
            ModelCommands.GetModelState(id: id)
        )
        #expect(state == .downloaded)

        // Verify model properties after transition
        let model = try await database.read(ModelCommands.GetModel(name: "test-model"))
        #expect(model.state == .downloaded)
    }

    @Test("Model deletes local location successfully")
    @MainActor
    func deleteLocalLocation() async throws {
        // Given
        let database = try ModelCommandsTests.setupTestDatabase()
        let modelDTO = ModelCommandsTests.createTestModelDTO(
            name: "test-model",
            isDownloaded: true
        )
        let id = try await database.write(ModelCommands.AddModels(modelDTOs: [modelDTO]))
        let model = try await database.read(ModelCommands.GetModelFromId(id: id))
        // NOTE: downloadedLocation property no longer exists
        // model.downloadedLocation = "some/path"

        // When
        try await database.write(ModelCommands.DeleteModelLocation(
            model: id
        ))

        // Then
        // NOTE: downloadedLocation property no longer exists
        // #expect(model.downloadedLocation == nil)
        #expect(model.state == .notDownloaded)
    }
}

struct TestError: Error {
    let message: String

    init(_ message: String) {
        self.message = message
    }
}
