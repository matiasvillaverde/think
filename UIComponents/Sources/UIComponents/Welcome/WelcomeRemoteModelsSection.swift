import Abstractions
import RemoteSession
import SwiftUI

internal struct WelcomeRemoteModelsSection: View {
    @Environment(\.remoteModelsViewModel)
    private var remoteModelsViewModel: RemoteModelsViewModeling

    @Binding var selectedModel: RemoteModel?

    @State private var selectedProvider: RemoteProviderType = .openAI
    @State private var models: [RemoteModel] = []
    @State private var isLoading: Bool = false
    @State private var errorMessage: String?
    @State private var searchText: String = ""
    @State private var isKeyConfigured: Bool = false
    @State private var lastSuccessfulModels: [RemoteModel] = []

    @State private var showingKeyEntry: Bool = false
    @State private var apiKeyInput: String = ""
    @State private var isSavingKey: Bool = false
    @State private var keyErrorMessage: String?

    var body: some View {
        WelcomeRemoteModelsSectionContent(
            selectedProvider: $selectedProvider,
            selectedModel: $selectedModel,
            searchText: $searchText,
            isKeyConfigured: isKeyConfigured,
            isLoading: isLoading,
            errorMessage: errorMessage,
            models: models,
            lastSuccessfulModels: lastSuccessfulModels,
            onRefresh: { Task { await refreshState() } },
            onRequestKeyEntry: {
                apiKeyInput = ""
                keyErrorMessage = nil
                showingKeyEntry = true
            }
        )
        .task(id: selectedProvider) {
            await refreshState()
        }
        .onChange(of: selectedProvider) { _, _ in
            selectedModel = nil
            searchText = ""
        }
        .sheet(isPresented: $showingKeyEntry) {
            APIKeyEntrySheet(
                provider: selectedProvider,
                apiKey: $apiKeyInput,
                isLoading: $isSavingKey,
                errorMessage: $keyErrorMessage,
                onSave: { await saveAPIKey() },
                onCancel: { dismissKeyEntry() }
            )
        }
    }

    @MainActor
    private func refreshState() async {
        isLoading = true
        await remoteModelsViewModel.loadModels(for: selectedProvider)
        await updateState()
    }

    @MainActor
    private func updateState() async {
        models = await remoteModelsViewModel.models
        isLoading = await remoteModelsViewModel.isLoading
        errorMessage = await remoteModelsViewModel.errorMessage
        isKeyConfigured = await remoteModelsViewModel.hasAPIKey(for: selectedProvider)

        if errorMessage == nil, !models.isEmpty {
            lastSuccessfulModels = models
        }
    }

    @MainActor
    private func saveAPIKey() async {
        guard !apiKeyInput.isEmpty else {
            keyErrorMessage = String(localized: "Please enter an API key", bundle: .module)
            return
        }

        isSavingKey = true
        keyErrorMessage = nil

        do {
            try await remoteModelsViewModel.saveAPIKey(apiKeyInput, for: selectedProvider)
            dismissKeyEntry()
            await refreshState()
        } catch {
            keyErrorMessage = String(localized: "Failed to save API key", bundle: .module)
        }

        isSavingKey = false
    }

    @MainActor
    private func dismissKeyEntry() {
        showingKeyEntry = false
        apiKeyInput = ""
        keyErrorMessage = nil
    }
}

#if DEBUG
#Preview {
    WelcomeRemoteModelsSection(selectedModel: .constant(nil))
        .padding()
}
#endif
