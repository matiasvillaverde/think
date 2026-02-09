import Abstractions
import RemoteSession
import SwiftUI

private enum WelcomeRemoteModelsConstants {
    static let freeBadgeHorizontalPadding: CGFloat = 6
    static let freeBadgeVerticalPadding: CGFloat = 2
    static let freeBadgeOpacity: Double = 0.15
    static let descriptionLineLimit: Int = 2
    static let rowPadding: CGFloat = 12
    static let rowCornerRadius: CGFloat = 10
    static let rowBorderWidth: CGFloat = 1
    static let listBottomPadding: CGFloat = 8
    static let sectionHeaderTopPadding: CGFloat = 4
}

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

    @State private var showingKeyEntry: Bool = false
    @State private var apiKeyInput: String = ""
    @State private var isSavingKey: Bool = false
    @State private var keyErrorMessage: String?

    var body: some View {
        VStack(spacing: WelcomeConstants.spacingMedium) {
            providerPicker
            keyStatusSection
            contentSection
        }
        .task(id: selectedProvider) {
            await refreshState()
        }
        .onChange(of: selectedProvider) { _, _ in
            selectedModel = nil
            searchText = ""
        }
        .sheet(isPresented: $showingKeyEntry) {
            keyEntrySheet
        }
    }

    // MARK: - Provider Picker

    private var providerPicker: some View {
        Picker(
            String(localized: "Provider", bundle: .module),
            selection: $selectedProvider
        ) {
            ForEach(RemoteProviderType.allCases, id: \.self) { provider in
                Text(provider.displayName).tag(provider)
            }
        }
        .pickerStyle(.segmented)
        .accessibilityLabel(
            Text(String(localized: "Remote provider", bundle: .module))
        )
    }

    // MARK: - Key Status

    private var keyStatusSection: some View {
        HStack(spacing: WelcomeConstants.spacingMedium) {
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
                    Image(systemName: "key.fill")
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
            keyRequiredView
        } else if isLoading {
            ProgressView()
                .frame(maxWidth: .infinity, alignment: .center)
        } else if let errorMessage {
            ContentUnavailableView(
                String(localized: "Unable to Load Models", bundle: .module),
                systemImage: "exclamationmark.triangle.fill",
                description: Text(errorMessage)
            )
        } else if filteredModels.isEmpty {
            ContentUnavailableView(
                String(localized: "No Models Found", bundle: .module),
                systemImage: "sparkles",
                description: Text(
                    String(
                        localized: "Try a different provider or adjust your search.",
                        bundle: .module
                    )
                )
            )
        } else {
            List {
                if !freeModels.isEmpty {
                    sectionHeader("Free Models")
                    modelRows(freeModels)
                }
                if !paidModels.isEmpty {
                    sectionHeader("Paid Models")
                    modelRows(paidModels)
                }
                if !otherModels.isEmpty {
                    sectionHeader("Other Models")
                    modelRows(otherModels)
                }
            }
            .listStyle(.plain)
            .searchable(text: $searchText)
            .frame(maxHeight: WelcomeConstants.maxScrollHeight)
            .padding(.bottom, WelcomeRemoteModelsConstants.listBottomPadding)
        }
    }

    private var keyRequiredView: some View {
        let providerName: String = selectedProvider.displayName
        return VStack(spacing: WelcomeConstants.spacingMedium) {
            ContentUnavailableView(
                String(localized: "Add an API Key", bundle: .module),
                systemImage: "key.fill",
                description: Text(
                    String(
                        localized: "Add your \(providerName) API key to load models.",
                        bundle: .module
                    )
                )
            )
            Button {
                apiKeyInput = ""
                keyErrorMessage = nil
                showingKeyEntry = true
            } label: {
                Text("Add API Key", bundle: .module)
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, alignment: .center)
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

    private var freeModels: [RemoteModel] {
        filteredModels.filter { $0.pricing == .free }
    }

    private var paidModels: [RemoteModel] {
        filteredModels.filter { $0.pricing == .paid }
    }

    private var otherModels: [RemoteModel] {
        filteredModels.filter { $0.pricing == .unknown }
    }

    @ViewBuilder
    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.caption)
            .foregroundStyle(Color.textSecondary)
            .textCase(.uppercase)
            .padding(.top, WelcomeRemoteModelsConstants.sectionHeaderTopPadding)
    }

    @ViewBuilder
    private func modelRows(_ models: [RemoteModel]) -> some View {
        ForEach(models) { model in
            WelcomeRemoteModelRow(
                model: model,
                isSelected: selectedModel?.id == model.id
            ) {
                selectedModel = model
            }
            .listRowSeparator(.hidden)
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

    // MARK: - State

    private func refreshState() async {
        isLoading = true
        await remoteModelsViewModel.loadModels(for: selectedProvider)
        await updateState()
    }

    private func updateState() async {
        models = await remoteModelsViewModel.models
        isLoading = await remoteModelsViewModel.isLoading
        errorMessage = await remoteModelsViewModel.errorMessage
        isKeyConfigured = await remoteModelsViewModel.hasAPIKey(for: selectedProvider)
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
}

private struct WelcomeRemoteModelRow: View {
    let model: RemoteModel
    let isSelected: Bool
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack(alignment: .top, spacing: WelcomeConstants.spacingMedium) {
                VStack(alignment: .leading, spacing: WelcomeConstants.spacingSmall) {
                    titleRow
                    modelIdRow
                    descriptionRow
                    contextRow
                }
                Spacer()
                selectionIndicator
            }
            .padding(WelcomeRemoteModelsConstants.rowPadding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.backgroundSecondary)
            .overlay(selectionBorder)
            .clipShape(
                RoundedRectangle(cornerRadius: WelcomeRemoteModelsConstants.rowCornerRadius)
            )
        }
        .buttonStyle(.plain)
    }

    private var titleRow: some View {
        HStack(spacing: WelcomeConstants.spacingSmall) {
            Text(model.displayName)
                .font(.headline)
                .foregroundStyle(Color.textPrimary)

            if model.pricing == .free {
                Text("Free", bundle: .module)
                    .font(.caption2)
                    .padding(.horizontal, WelcomeRemoteModelsConstants.freeBadgeHorizontalPadding)
                    .padding(.vertical, WelcomeRemoteModelsConstants.freeBadgeVerticalPadding)
                    .background(
                        Color.paletteGreen.opacity(WelcomeRemoteModelsConstants.freeBadgeOpacity)
                    )
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
                .lineLimit(WelcomeRemoteModelsConstants.descriptionLineLimit)
        }
    }

    @ViewBuilder private var contextRow: some View {
        if let contextLength = model.contextLength {
            Text(
                String(
                    localized: "Context: \(contextLength) tokens",
                    bundle: .module
                )
            )
            .font(.caption)
            .foregroundStyle(Color.textSecondary)
        }
    }

    private var selectionIndicator: some View {
        Group {
            if isSelected {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                    .accessibilityHidden(true)
            } else {
                Image(systemName: "circle")
                    .foregroundStyle(Color.textSecondary)
                    .accessibilityHidden(true)
            }
        }
        .font(.title3)
    }

    private var selectionBorder: some View {
        RoundedRectangle(cornerRadius: WelcomeRemoteModelsConstants.rowCornerRadius)
            .stroke(
                isSelected ? Color.marketingPrimary : Color.buttonStroke,
                lineWidth: WelcomeRemoteModelsConstants.rowBorderWidth
            )
    }
}

#if DEBUG
#Preview {
    WelcomeRemoteModelsSection(selectedModel: .constant(nil))
        .padding()
}
#endif
