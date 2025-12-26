import Foundation

/// Protocol for managing remote provider models in the UI.
public protocol RemoteModelsViewModeling: Actor {
    /// Currently loaded models.
    var models: [RemoteModel] { get async }
    /// Whether a model refresh is in progress.
    var isLoading: Bool { get async }
    /// Current error message (if any).
    var errorMessage: String? { get async }

    /// Loads models for a provider.
    func loadModels(for provider: RemoteProviderType) async

    /// Checks if a provider has an API key configured.
    func hasAPIKey(for provider: RemoteProviderType) async -> Bool

    /// Saves an API key for a provider.
    func saveAPIKey(_ key: String, for provider: RemoteProviderType) async throws

    /// Removes an API key for a provider.
    func removeAPIKey(for provider: RemoteProviderType) async throws

    /// Creates (or updates) a remote model entry and returns its ID.
    func selectModel(_ model: RemoteModel, chatId: UUID) async throws -> UUID
}
