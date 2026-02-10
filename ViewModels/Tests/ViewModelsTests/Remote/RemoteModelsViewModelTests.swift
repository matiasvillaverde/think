import Abstractions
import AbstractionsTestUtilities
@testable import Database
import Foundation
import RemoteSession
import Testing
@testable import ViewModels

@Suite("Remote Models ViewModel Tests")
internal struct RemoteModelsViewModelTests {
    private struct MockRemoteModelsProvider: RemoteModelsProviding {
        let models: [RemoteModel]

        func listModels(for provider: RemoteProviderType, apiKey: String?) async throws -> [RemoteModel] {
            _ = (provider, apiKey)
            try Task.checkCancellation()
            await Task.yield()
            return models
        }
    }

    private func createTestDatabase() throws -> Database {
        let config: DatabaseConfiguration = DatabaseConfiguration(
            isStoredInMemoryOnly: true,
            allowsSave: true,
            ragFactory: MockRagFactory(mockRag: MockRagging())
        )
        return try Database.new(configuration: config)
    }

    @Test("Loads models when API key is configured")
    @MainActor
    func loadsModelsWithKey() async throws {
        let database: Database = try createTestDatabase()
        _ = try await database.execute(AppCommands.Initialize())

        let provider: MockRemoteModelsProvider = MockRemoteModelsProvider(
            models: [
                RemoteModel(
                    provider: .openRouter,
                    modelId: "openai/gpt-4o-mini",
                    displayName: "GPT-4o Mini"
                )
            ]
        )
        let apiKeyManager: MockAPIKeyManager = MockAPIKeyManager(
            keys: [.openRouter: "test-key"]
        )

        let viewModel: RemoteModelsViewModel = RemoteModelsViewModel(
            database: database,
            apiKeyManager: apiKeyManager,
            remoteModelsProvider: provider
        )

        await viewModel.loadModels(for: .openRouter)

        let models: [RemoteModel] = await viewModel.models
        let error: String? = await viewModel.errorMessage

        #expect(models.count == 1)
        #expect(error == nil)
    }

    @Test("Reports error when API key is missing")
    @MainActor
    func reportsMissingKey() async throws {
        let database: Database = try createTestDatabase()
        _ = try await database.execute(AppCommands.Initialize())

        let provider: MockRemoteModelsProvider = MockRemoteModelsProvider(models: [])
        let apiKeyManager: MockAPIKeyManager = MockAPIKeyManager(keys: [:])

        let viewModel: RemoteModelsViewModel = RemoteModelsViewModel(
            database: database,
            apiKeyManager: apiKeyManager,
            remoteModelsProvider: provider
        )

        await viewModel.loadModels(for: .openRouter)
        let error: String? = await viewModel.errorMessage

        #expect(error != nil)
    }

    @Test("SelectModel persists remote model")
    @MainActor
    func selectModelPersistsRemoteModel() async throws {
        let database: Database = try createTestDatabase()
        _ = try await database.execute(AppCommands.Initialize())

        let provider: MockRemoteModelsProvider = MockRemoteModelsProvider(models: [])
        let apiKeyManager: MockAPIKeyManager = MockAPIKeyManager(
            keys: [.openRouter: "test-key"]
        )

        let viewModel: RemoteModelsViewModel = RemoteModelsViewModel(
            database: database,
            apiKeyManager: apiKeyManager,
            remoteModelsProvider: provider
        )

        let model: RemoteModel = RemoteModel(
            provider: .openRouter,
            modelId: "openai/gpt-4o-mini",
            displayName: "GPT-4o Mini"
        )

        let modelId: UUID = try await viewModel.selectModel(model, chatId: UUID())
        let stored: Model? = try await database.read(
            ModelCommands.GetModelByLocation(location: model.location)
        )

        #expect(stored?.id == modelId)
        #expect(stored?.backend == .remote)
        #expect(stored?.locationKind == .remote)
        #expect(stored?.architecture == .gpt || stored?.architecture == .harmony)
    }
}
