import Abstractions
import Foundation

internal final actor PreviewRemoteModelsViewModel: RemoteModelsViewModeling {
    private enum PreviewConstants {
        static let miniContextLength: Int = 128_000
        static let freeContextLength: Int = 32_000
    }

    private var storedModels: [RemoteModel] = [
        RemoteModel(
            provider: .openRouter,
            modelId: "openai/gpt-4o-mini",
            displayName: "GPT-4o Mini",
            description: "Preview remote model",
            contextLength: PreviewConstants.miniContextLength,
            type: .language,
            pricing: .paid
        ),
        RemoteModel(
            provider: .openRouter,
            modelId: "meta-llama/llama-3.2-3b-instruct:free",
            displayName: "Llama 3.2 3B Instruct (Free)",
            description: "Preview free remote model",
            contextLength: PreviewConstants.freeContextLength,
            type: .language,
            pricing: .free
        )
    ]

    private var isLoadingState: Bool = false
    private var errorState: String?

    var models: [RemoteModel] { storedModels }
    var isLoading: Bool { isLoadingState }
    var errorMessage: String? { errorState }

    func loadModels(for provider: RemoteProviderType) async {
        _ = provider
        await Task.yield()
    }

    func hasAPIKey(for provider: RemoteProviderType) async -> Bool {
        _ = provider
        await Task.yield()
        return true
    }

    func saveAPIKey(_ key: String, for provider: RemoteProviderType) async throws {
        _ = (key, provider)
        try Task.checkCancellation()
        await Task.yield()
    }

    func removeAPIKey(for provider: RemoteProviderType) async throws {
        _ = provider
        try Task.checkCancellation()
        await Task.yield()
    }

    func selectModel(_ model: RemoteModel, chatId: UUID) async throws -> UUID {
        _ = (model, chatId)
        try Task.checkCancellation()
        await Task.yield()
        return UUID()
    }
}
