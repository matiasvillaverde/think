import Abstractions
import RemoteSession
import SwiftUI

// MARK: - Constants

private enum APIKeyConstants {
    static let sectionSpacing: CGFloat = 24
    static let itemSpacing: CGFloat = 12
    static let contentPadding: CGFloat = 16
    static let cornerRadius: CGFloat = 12
    static let iconSize: CGFloat = 32
    static let statusIconSize: CGFloat = 16
    static let hoverAnimationDuration: Double = 0.15
    static let hoverOpacity: Double = 0.05
    static let progressScale: CGFloat = 0.8
    static let sheetMinWidth: CGFloat = 400
    static let sheetPadding: CGFloat = 24
    static let headerSpacing: CGFloat = 8
    static let inputSpacing: CGFloat = 8
    static let buttonSpacing: CGFloat = 12
    static let rowSpacing: CGFloat = 12
    static let rowPadding: CGFloat = 12
    static let rowStatusSpacing: CGFloat = 4
    static let menuWidth: CGFloat = 32
    static let actionSpacing: CGFloat = 20
}

// MARK: - API Key Settings View

/// View for managing API keys for remote LLM providers.
public struct APIKeySettingsView: View {
    @State private var providerStates: [ProviderState] = RemoteProviderType
        .allCases
        .map { ProviderState(provider: $0) }
    @State private var selectedProvider: RemoteProviderType?
    @State private var apiKeyInput: String = ""
    @State private var showingKeyEntry: Bool = false
    @State private var isLoading: Bool = false
    @State private var errorMessage: String?

    private let apiKeyManager: APIKeyManaging

    /// Creates a new API key settings view.
    public init(apiKeyManager: APIKeyManaging = APIKeyManager.shared) {
        self.apiKeyManager = apiKeyManager
    }

    public var body: some View {
        VStack(spacing: APIKeyConstants.sectionSpacing) {
            headerSection
            providerList
            Spacer()
        }
        .padding(APIKeyConstants.contentPadding)
        .task {
            await loadConfiguration()
        }
        .sheet(isPresented: $showingKeyEntry) {
            keyEntrySheet
        }
    }

    private var headerSection: some View {
        APIKeyHeaderView()
    }

    private var providerList: some View {
        VStack(spacing: APIKeyConstants.itemSpacing) {
            ForEach(providerStates) { state in
                APIKeyProviderRow(
                    state: state,
                    onConfigure: { configureProvider(state.provider) },
                    onRemove: { Task { await removeAPIKey(for: state.provider) } }
                )
            }
        }
    }

    @ViewBuilder private var keyEntrySheet: some View {
        if let provider = selectedProvider {
            APIKeyEntrySheet(
                provider: provider,
                apiKey: $apiKeyInput,
                isLoading: $isLoading,
                errorMessage: $errorMessage,
                onSave: { await saveAPIKey(for: provider) },
                onCancel: { dismissKeyEntry() }
            )
        }
    }

    private func loadConfiguration() async {
        var updatedStates: [ProviderState] = []
        for provider in RemoteProviderType.allCases {
            let hasKey: Bool = await apiKeyManager.hasKey(for: provider)
            updatedStates.append(ProviderState(provider: provider, isConfigured: hasKey))
        }
        providerStates = updatedStates
    }

    private func configureProvider(_ provider: RemoteProviderType) {
        selectedProvider = provider
        apiKeyInput = ""
        errorMessage = nil
        showingKeyEntry = true
    }

    private func saveAPIKey(for provider: RemoteProviderType) async {
        guard !apiKeyInput.isEmpty else {
            errorMessage = String(
                localized: "Please enter an API key",
                bundle: .module
            )
            return
        }

        isLoading = true
        errorMessage = nil

        do {
            try await apiKeyManager.setKey(apiKeyInput, for: provider)
            NotificationCenter.default.post(name: .remoteAPIKeysDidChange, object: nil)
            if let index = providerStates.firstIndex(where: { $0.provider == provider }) {
                providerStates[index] = ProviderState(provider: provider, isConfigured: true)
            }
            dismissKeyEntry()
        } catch {
            errorMessage = String(
                localized: "Failed to save API key",
                bundle: .module
            )
        }

        isLoading = false
    }

    private func removeAPIKey(for provider: RemoteProviderType) async {
        do {
            try await apiKeyManager.deleteKey(for: provider)
            NotificationCenter.default.post(name: .remoteAPIKeysDidChange, object: nil)
            if let index = providerStates.firstIndex(where: { $0.provider == provider }) {
                providerStates[index] = ProviderState(provider: provider, isConfigured: false)
            }
        } catch {
            // Silently handle error
        }
    }

    private func dismissKeyEntry() {
        showingKeyEntry = false
        apiKeyInput = ""
        selectedProvider = nil
        errorMessage = nil
    }
}

// MARK: - Preview

#if DEBUG
#Preview {
    APIKeySettingsView(apiKeyManager: MockAPIKeyManager(keys: [.openRouter: "test"]))
}
#endif
