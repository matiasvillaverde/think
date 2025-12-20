import Testing
import Foundation
import SwiftData
@testable import Database
import AbstractionsTestUtilities
import Abstractions

@Suite("App Initialization - Runtime State Reset")
struct AppInitializationRuntimeStateTests {
    @Test("Resets all model runtime states to notLoaded on app startup")
    @MainActor
    func resetsAllModelRuntimeStatesToNotLoaded() async throws {
        // Given - Database with existing user and models in various runtime states
        let mockRag = MockRagging()
        let config = DatabaseConfiguration(
            isStoredInMemoryOnly: true,
            allowsSave: true,
            ragFactory: MockRagFactory(mockRag: mockRag)
        )
        let database = try Database.new(configuration: config)
        
        // Create user with models
        let user = User()
        database.modelContainer.mainContext.insert(user)
        
        // Create v2 language model with various runtime states
        let languageModelDTO = ModelDTO(
            type: .language,
            backend: .coreml,
            name: "test-language-model",
            displayName: "Test Language Model",
            displayDescription: "Test model for runtime state",
            author: "Test Author",
            license: "MIT",
            licenseUrl: "https://test.com/license",
            tags: ["test", "language"],
            downloads: 1000,
            likes: 100,
            lastModified: Date(),
            skills: ["text-generation"],
            parameters: 1_000_000_000,
            ramNeeded: 4_000_000_000,
            size: 2_000_000_000,
            locationHuggingface: "test/language-model",
            version: 2,
            architecture: .unknown
        )
        
        let imageModelDTO = ModelDTO(
            type: .diffusion,
            backend: .coreml,
            name: "test-image-model",
            displayName: "Test Image Model",
            displayDescription: "Test image model",
            author: "Test Author",
            license: "MIT",
            licenseUrl: "https://test.com/license",
            tags: ["test", "image"],
            downloads: 500,
            likes: 50,
            lastModified: Date(),
            skills: ["image-generation"],
            parameters: 500_000_000,
            ramNeeded: 2_000_000_000,
            size: 1_000_000_000,
            locationHuggingface: "test/image-model",
            version: 2,
            architecture: .unknown
        )
        
        let languageModel = try languageModelDTO.createModel()
        languageModel.state = Model.State.downloaded
        languageModel.runtimeState = Model.RuntimeState.loaded
        
        let imageModel = try imageModelDTO.createModel()
        imageModel.state = Model.State.downloaded
        imageModel.runtimeState = Model.RuntimeState.generating
        
        let errorModel = try ModelDTO(
            type: .language,
            backend: .coreml,
            name: "error-model",
            displayName: "Error Model",
            displayDescription: "Model in error state",
            author: "Test",
            license: "MIT",
            licenseUrl: nil,
            tags: [],
            downloads: 0,
            likes: 0,
            lastModified: nil,
            skills: [],
            parameters: 1_000_000,
            ramNeeded: 1_000_000,
            size: 1_000_000,
            locationHuggingface: "test/error-model",
            version: 2,
            architecture: .unknown
        ).createModel()
        errorModel.state = Model.State.downloaded
        errorModel.runtimeState = Model.RuntimeState.error
        
        database.modelContainer.mainContext.insert(languageModel)
        database.modelContainer.mainContext.insert(imageModel)
        database.modelContainer.mainContext.insert(errorModel)
        
        user.models.append(languageModel)
        user.models.append(imageModel)
        user.models.append(errorModel)
        
        try database.modelContainer.mainContext.save()
        
        // Verify initial states
        #expect(languageModel.runtimeState == Model.RuntimeState.loaded)
        #expect(imageModel.runtimeState == Model.RuntimeState.generating)
        #expect(errorModel.runtimeState == Model.RuntimeState.error)
        
        // When - Initialize app (which should reset all runtime states)
        _ = try await database.execute(AppCommands.Initialize())
        
        // Then - All models should have runtime state reset to .notLoaded
        #expect(languageModel.runtimeState == Model.RuntimeState.notLoaded)
        #expect(imageModel.runtimeState == Model.RuntimeState.notLoaded)
        #expect(errorModel.runtimeState == Model.RuntimeState.notLoaded)
    }
    
    @Test("Handles models with nil runtime state gracefully")
    @MainActor
    func handlesNilRuntimeStateGracefully() async throws {
        // Given - Database with existing user and both language and image models
        let mockRag = MockRagging()
        let config = DatabaseConfiguration(
            isStoredInMemoryOnly: true,
            allowsSave: true,
            ragFactory: MockRagFactory(mockRag: mockRag)
        )
        let database = try Database.new(configuration: config)
        
        // Create user with both language and image models (required for chat creation)
        let user = User()
        database.modelContainer.mainContext.insert(user)
        
        let languageModelDTO = ModelDTO(
            type: .language,
            backend: .coreml,
            name: "test-language-model",
            displayName: "Test Language Model",
            displayDescription: "Test",
            author: "Test",
            license: "MIT",
            licenseUrl: nil,
            tags: [],
            downloads: 0,
            likes: 0,
            lastModified: nil,
            skills: [],
            parameters: 1_000_000,
            ramNeeded: 1_000_000,
            size: 1_000_000,
            locationHuggingface: "test/language-model",
            version: 2,
            architecture: .unknown
        )
        
        let imageModelDTO = ModelDTO(
            type: .diffusion,
            backend: .coreml,
            name: "test-image-model",
            displayName: "Test Image Model",
            displayDescription: "Test",
            author: "Test",
            license: "MIT",
            licenseUrl: nil,
            tags: [],
            downloads: 0,
            likes: 0,
            lastModified: nil,
            skills: [],
            parameters: 1_000_000,
            ramNeeded: 1_000_000,
            size: 1_000_000,
            locationHuggingface: "test/image-model",
            version: 2,
            architecture: .unknown
        )
        
        let languageModel = try languageModelDTO.createModel()
        languageModel.state = Model.State.downloaded
        // Model's runtimeState should already be .notLoaded by default
        
        let imageModel = try imageModelDTO.createModel()
        imageModel.state = Model.State.downloaded
        // Model's runtimeState should already be .notLoaded by default
        
        database.modelContainer.mainContext.insert(languageModel)
        database.modelContainer.mainContext.insert(imageModel)
        user.models.append(languageModel)
        user.models.append(imageModel)
        
        try database.modelContainer.mainContext.save()
        
        // When - Initialize app
        let result = try await database.execute(AppCommands.Initialize())
        
        // Then - Should complete successfully without crash
        #expect(result.userId == user.id)
        #expect(languageModel.runtimeState == Model.RuntimeState.notLoaded)
        #expect(imageModel.runtimeState == Model.RuntimeState.notLoaded)
    }
    
    @Test("Runtime state reset works with empty model list")
    @MainActor
    func runtimeStateResetWorksWithEmptyModelList() async throws {
        // Given - Database with user but no models
        let mockRag = MockRagging()
        let config = DatabaseConfiguration(
            isStoredInMemoryOnly: true,
            allowsSave: true,
            ragFactory: MockRagFactory(mockRag: mockRag)
        )
        let database = try Database.new(configuration: config)
        
        let user = User()
        database.modelContainer.mainContext.insert(user)
        try database.modelContainer.mainContext.save()
        
        // When - Initialize app
        let result = try await database.execute(AppCommands.Initialize())
        
        // Then - Should complete successfully
        #expect(result.userId == user.id)
        #expect(result.targetScreen == .welcome) // No models, so welcome screen
    }
}
