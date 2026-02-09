import Abstractions
import Database
import RemoteSession
import SwiftUI

// MARK: - Remote Models View

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

    @State private var selectedProvider: RemoteProviderType = .openRouter
    @State private var models: [RemoteModel] = []
    @State private var isLoading: Bool = false
    @State private var errorMessage: String?
    @State private var searchText: String = ""
    @State private var isKeyConfigured: Bool = false

    @State private var showingKeyEntry: Bool = false
    @State private var apiKeyInput: String = ""
    @State private var isSavingKey: Bool = false
    @State private var keyErrorMessage: String?

    @State private var isSelectingModel: Bool = false

    var body: some View {
        VStack(spacing: DesignConstants.Spacing.large) {
            headerSection
            providerPicker
            keyStatusSection
            contentSection
        }
        .padding(DesignConstants.Spacing.large)
        .task(id: selectedProvider) {
            await refreshState()
            await loadModels()
        }
        .sheet(isPresented: $showingKeyEntry) {
            keyEntrySheet
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: DesignConstants.Spacing.small) {
            Text("Remote Models", bundle: .module)
                .font(.title2)
                .fontWeight(.semibold)
            Text(
                "Use your provider API key to run models in the cloud.",
                bundle: .module
            )
            .font(.subheadline)
            .foregroundStyle(Color.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Provider Picker

    private var providerPicker: some View {
        Picker("Provider", selection: $selectedProvider) {
            ForEach(RemoteProviderType.allCases, id: \.self) { provider in
                Text(provider.displayName).tag(provider)
            }
        }
        #if os(macOS)
        .pickerStyle(.segmented)
        #else
        .pickerStyle(.segmented)
        #endif
    }

    // MARK: - API Key Status

    private var keyStatusSection: some View {
        HStack(spacing: DesignConstants.Spacing.standard) {
            if isKeyConfigured {
                Label {
                    Text("API key configured", bundle: .module)
                } icon: {
                    Image(systemName: "checkmark.seal.fill")
                        .foregroundStyle(.green)
                        .accessibilityHidden(true)
                }
            } else {
                Label {
                    Text("API key required", bundle: .module)
                } icon: {
                    Image(systemName: "key")
                        .foregroundStyle(.orange)
                        .accessibilityHidden(true)
                }
            }

            Spacer()

            Button {
                apiKeyInput = ""
                keyErrorMessage = nil
                showingKeyEntry = true
            } label: {
                Text(isKeyConfigured ? "Update Key" : "Add Key", bundle: .module)
            }
            .buttonStyle(.bordered)
        }
    }

    // MARK: - Content

    @ViewBuilder private var contentSection: some View {
        if !isKeyConfigured {
            RemoteModelsKeyRequiredView(
                providerName: selectedProvider.displayName
            ) {
                apiKeyInput = ""
                keyErrorMessage = nil
                showingKeyEntry = true
            }
        } else if isLoading {
            ProgressView()
                .frame(maxWidth: .infinity, alignment: .center)
        } else if let errorMessage {
            ContentUnavailableView(
                "Unable to Load Models",
                systemImage: "exclamationmark.triangle.fill",
                description: Text(errorMessage)
            )
        } else if filteredModels.isEmpty {
            ContentUnavailableView(
                "No Models Found",
                systemImage: "sparkles",
                description: Text(
                    "Try a different provider or adjust your search.",
                    bundle: .module
                )
            )
        } else {
            RemoteModelsListView(
                models: filteredModels,
                searchText: $searchText,
                isSelectingModel: isSelectingModel,
                isSelected: isSelected,
                onSelect: select
            )
        }
    }

    // MARK: - Key Entry Sheet

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

    // MARK: - Actions

    private func refreshState() async {
        models = await remoteModelsViewModel.models
        isLoading = await remoteModelsViewModel.isLoading
        errorMessage = await remoteModelsViewModel.errorMessage
        isKeyConfigured = await remoteModelsViewModel.hasAPIKey(for: selectedProvider)
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
        let languageOnly: [RemoteModel] = models.filter { model in
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
}

// MARK: - Remote Model Row

internal struct RemoteModelRow: View {
    let model: RemoteModel
    let isSelected: Bool
    let isSelecting: Bool
    let onSelect: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: DesignConstants.Spacing.standard) {
            detailsSection
            Spacer()
            actionSection
        }
        .padding(.vertical, DesignConstants.Spacing.small)
    }

    private var detailsSection: some View {
        VStack(alignment: .leading, spacing: DesignConstants.Spacing.small) {
            titleRow
            modelIdRow
            descriptionRow
            contextRow
        }
    }

    private var titleRow: some View {
        HStack(spacing: DesignConstants.Spacing.small) {
            Text(model.displayName)
                .font(.headline)

            if model.pricing == .free {
                Text("Free", bundle: .module)
                    .font(.caption2)
                    .padding(.horizontal, RemoteModelsViewConstants.freeBadgeHorizontalPadding)
                    .padding(.vertical, RemoteModelsViewConstants.freeBadgeVerticalPadding)
                    .background(Color.paletteGreen.opacity(RemoteModelsViewConstants.freeBadgeOpacity))
                    .clipShape(Capsule())
            }
        }
    }

    private var modelIdRow: some View {
        Text(model.modelId)
            .font(.caption)
            .foregroundStyle(Color.textSecondary)
    }

    @ViewBuilder private var descriptionRow: some View {
        if let description = model.description, !description.isEmpty {
            Text(description)
                .font(.footnote)
                .foregroundStyle(Color.textSecondary)
                .lineLimit(RemoteModelsViewConstants.descriptionLineLimit)
        }
    }

    @ViewBuilder private var contextRow: some View {
        if let contextLength = model.contextLength {
            Text("Context: \(contextLength) tokens", bundle: .module)
                .font(.caption)
                .foregroundStyle(Color.textSecondary)
        }
    }

    @ViewBuilder private var actionSection: some View {
        if isSelected {
            Label("Selected", systemImage: "checkmark.circle.fill")
                .labelStyle(.titleAndIcon)
                .foregroundStyle(.green)
        } else {
            Button {
                onSelect()
            } label: {
                if isSelecting {
                    ProgressView()
                } else {
                    Text("Use", bundle: .module)
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(isSelecting)
        }
    }
}
