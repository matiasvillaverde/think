import Abstractions
import Database
import Foundation
import OSLog
import RemoteSession

/// View model for listing and selecting remote provider models.
public final actor RemoteModelsViewModel: RemoteModelsViewModeling {
    private let logger: Logger = Logger(
        subsystem: "ViewModels",
        category: String(describing: RemoteModelsViewModel.self)
    )

    private let database: DatabaseProtocol
    private let apiKeyManager: APIKeyManaging
    private let remoteModelsProvider: RemoteModelsProviding

    private var internalModels: [RemoteModel] = []
    private var internalIsLoading: Bool = false
    private var internalErrorMessage: String?

    public var models: [RemoteModel] { internalModels }
    public var isLoading: Bool { internalIsLoading }
    public var errorMessage: String? { internalErrorMessage }

    public init(
        database: DatabaseProtocol,
        apiKeyManager: APIKeyManaging = APIKeyManager.shared,
        remoteModelsProvider: RemoteModelsProviding = RemoteModelsService()
    ) {
        self.database = database
        self.apiKeyManager = apiKeyManager
        self.remoteModelsProvider = remoteModelsProvider
    }

    public func loadModels(for provider: RemoteProviderType) async {
        internalIsLoading = true
        internalErrorMessage = nil
        internalModels = []

        let apiKey: String? = try? await apiKeyManager.getKey(for: provider)
        guard let apiKey, !apiKey.isEmpty else {
            internalIsLoading = false
            internalErrorMessage = String(
                localized: "Add an API key for \(provider.displayName) to load models.",
                bundle: .module
            )
            return
        }

        do {
            let models: [RemoteModel] = try await remoteModelsProvider.listModels(
                for: provider,
                apiKey: apiKey
            )
            internalModels = models.sorted { first, second in
                first.displayName.localizedCaseInsensitiveCompare(second.displayName) == .orderedAscending
            }
        } catch {
            logger.error("Failed to load models: \(error.localizedDescription)")
            internalErrorMessage = String(
                localized: "Failed to load models. Please try again.",
                bundle: .module
            )
        }

        internalIsLoading = false
    }

    public func hasAPIKey(for provider: RemoteProviderType) async -> Bool {
        await apiKeyManager.hasKey(for: provider)
    }

    public func saveAPIKey(_ key: String, for provider: RemoteProviderType) async throws {
        try await apiKeyManager.setKey(key, for: provider)
    }

    public func removeAPIKey(for provider: RemoteProviderType) async throws {
        try await apiKeyManager.deleteKey(for: provider)
    }

    public func selectModel(_ model: RemoteModel, chatId: UUID) async throws -> UUID {
        _ = chatId
        return try await database.write(
            ModelCommands.CreateRemoteModel(
                name: model.modelId,
                displayName: model.displayName,
                displayDescription: model.description ?? model.displayName,
                location: model.location,
                type: model.type,
                architecture: .unknown
            )
        )
    }
}
