import Abstractions
import Database
import RemoteSession
import SwiftUI

internal enum RemoteModelsViewConstants {
    static let freeBadgeHorizontalPadding: CGFloat = 6
    static let freeBadgeVerticalPadding: CGFloat = 2
    static let freeBadgeOpacity: Double = 0.15
    static let descriptionLineLimit: Int = 2
    static let sectionHeaderTopPadding: CGFloat = 4
}

internal struct RemoteModelsView: View {
    @Environment(\.remoteModelsViewModel)
    private var remoteModelsViewModel: RemoteModelsViewModeling

    @Environment(\.generator)
    private var generator: ViewModelGenerating

    @Bindable var chat: Chat

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

    @State private var isSelectingModel: Bool = false

    var body: some View {
        List {
            providerSection
            modelsSection
        }
        #if os(macOS)
        .listStyle(.inset)
        .searchable(text: $searchText, placement: .toolbar)
        #else
        .listStyle(.insetGrouped)
        .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .automatic))
        #endif
        .task(id: selectedProvider) {
            await refreshState()
            await loadModels()
        }
        .sheet(isPresented: $showingKeyEntry) {
            keyEntrySheet
        }
    }

    private var providerSection: some View {
        RemoteModelsProviderSection(
            selectedProvider: $selectedProvider,
            isKeyConfigured: isKeyConfigured
        ) {
            apiKeyInput = ""
            keyErrorMessage = nil
            showingKeyEntry = true
        }
    }

    private var modelsSection: some View {
        RemoteModelsModelsSection(
            providerName: selectedProvider.displayName,
            isKeyConfigured: isKeyConfigured,
            isLoading: isLoading,
            errorMessage: errorMessage,
            searchText: searchText,
            models: filteredModels,
            freeModels: freeModels,
            paidModels: paidModels,
            otherModels: otherModels,
            isSelectingModel: isSelectingModel,
            isSelected: { isSelected($0) },
            onSelect: { select($0) },
            onRetry: { Task { await loadModels() } },
            onShowKeyEntry: {
                apiKeyInput = ""
                keyErrorMessage = nil
                showingKeyEntry = true
            }
        )
    }

    @ViewBuilder private var keyEntrySheet: some View {
        APIKeyEntrySheet(
            provider: selectedProvider,
            apiKey: $apiKeyInput,
            isLoading: $isSavingKey,
            errorMessage: $keyErrorMessage,
            onSave: { await saveAPIKey() },
            onCancel: { dismissKeyEntry() }
        )
    }

    private func refreshState() async {
        models = await remoteModelsViewModel.models
        isLoading = await remoteModelsViewModel.isLoading
        errorMessage = await remoteModelsViewModel.errorMessage
        isKeyConfigured = await remoteModelsViewModel.hasAPIKey(for: selectedProvider)

        if errorMessage == nil, !models.isEmpty {
            lastSuccessfulModels = models
        }
    }

    private func loadModels() async {
        await remoteModelsViewModel.loadModels(for: selectedProvider)
        await refreshState()
    }

    private func saveAPIKey() async {
        guard !apiKeyInput.isEmpty else {
            keyErrorMessage = String(localized: "Please enter an API key", bundle: .module)
            return
        }

        isSavingKey = true
        keyErrorMessage = nil

        do {
            try await remoteModelsViewModel.saveAPIKey(apiKeyInput, for: selectedProvider)
            NotificationCenter.default.post(name: .remoteAPIKeysDidChange, object: nil)
            dismissKeyEntry()
            await refreshState()
            await loadModels()
        } catch {
            keyErrorMessage = String(localized: "Failed to save API key", bundle: .module)
        }

        isSavingKey = false
    }

    private func dismissKeyEntry() {
        showingKeyEntry = false
        apiKeyInput = ""
        keyErrorMessage = nil
    }

    private func select(_ model: RemoteModel) {
        guard !isSelectingModel else {
            return
        }
        isSelectingModel = true

        Task {
            do {
                let modelId: UUID = try await remoteModelsViewModel.selectModel(
                    model,
                    chatId: chat.id
                )
                await generator.modify(chatId: chat.id, modelId: modelId)
            } catch {
                errorMessage = error.localizedDescription
            }
            isSelectingModel = false
        }
    }

    private func isSelected(_ model: RemoteModel) -> Bool {
        chat.languageModel.locationKind == .remote &&
            chat.languageModel.locationHuggingface == model.location
    }

    private var filteredModels: [RemoteModel] {
        // If we hit an error, prefer showing the last good list instead of an empty state.
        let base: [RemoteModel] = models.isEmpty ? lastSuccessfulModels : models

        let languageOnly: [RemoteModel] = base.filter { model in
            switch model.type {
            case .language, .deepLanguage, .flexibleThinker:
                return true

            case .diffusion, .diffusionXL, .visualLanguage:
                return false
            }
        }

        guard !searchText.isEmpty else {
            return languageOnly
        }

        return languageOnly.filter { model in
            model.displayName.localizedCaseInsensitiveContains(searchText) ||
                model.modelId.localizedCaseInsensitiveContains(searchText)
        }
    }

    private var freeModels: [RemoteModel] { filteredModels.filter { $0.pricing == .free } }
    private var paidModels: [RemoteModel] { filteredModels.filter { $0.pricing == .paid } }
    private var otherModels: [RemoteModel] { filteredModels.filter { $0.pricing == .unknown } }
}
