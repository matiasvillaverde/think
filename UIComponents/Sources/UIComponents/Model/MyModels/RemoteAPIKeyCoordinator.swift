import Abstractions
import RemoteSession
import SwiftUI

internal struct RemoteAPIKeyCoordinator: View {
    @Binding var providerKeyStatus: [RemoteProviderType: Bool]
    @Binding var keyEntryRequest: RemoteProviderType?

    @Environment(\.apiKeyManager)
    private var apiKeyManager: APIKeyManaging

    @State private var apiKeyInput: String = ""
    @State private var isSavingKey: Bool = false
    @State private var keyErrorMessage: String?

    var body: some View {
        Color.backgroundPrimary.opacity(0)
            .task { await refreshProviderKeyStatus() }
            .onReceive(NotificationCenter.default.publisher(for: .remoteAPIKeysDidChange)) { _ in
                Task { await refreshProviderKeyStatus() }
            }
            .sheet(
                isPresented: Binding(
                    get: { keyEntryRequest != nil },
                    set: { newValue in
                        if !newValue {
                            dismissKeyEntry()
                        }
                    }
                )
            ) {
                if let provider = keyEntryRequest {
                    APIKeyEntrySheet(
                        provider: provider,
                        apiKey: $apiKeyInput,
                        isLoading: $isSavingKey,
                        errorMessage: $keyErrorMessage,
                        onSave: { await saveAPIKey(for: provider) },
                        onCancel: { dismissKeyEntry() }
                    )
                }
            }
    }

    private func refreshProviderKeyStatus() async {
        var status: [RemoteProviderType: Bool] = [:]
        for provider in RemoteProviderType.allCases {
            status[provider] = await apiKeyManager.hasKey(for: provider)
        }
        providerKeyStatus = status
    }

    private func saveAPIKey(for provider: RemoteProviderType) async {
        guard !apiKeyInput.isEmpty else {
            keyErrorMessage = String(localized: "Please enter an API key", bundle: .module)
            return
        }

        isSavingKey = true
        keyErrorMessage = nil

        do {
            try await apiKeyManager.setKey(apiKeyInput, for: provider)
            NotificationCenter.default.post(name: .remoteAPIKeysDidChange, object: nil)
            dismissKeyEntry()
            await refreshProviderKeyStatus()
        } catch {
            keyErrorMessage = String(localized: "Failed to save API key", bundle: .module)
        }

        isSavingKey = false
    }

    private func dismissKeyEntry() {
        keyEntryRequest = nil
        apiKeyInput = ""
        keyErrorMessage = nil
    }
}
