import Abstractions
import RemoteSession
import SwiftUI

internal struct WelcomeRemoteModelsSectionContent: View {
    @Binding var selectedProvider: RemoteProviderType
    @Binding var selectedModel: RemoteModel?
    @Binding var searchText: String

    let isKeyConfigured: Bool
    let isLoading: Bool
    let errorMessage: String?
    let models: [RemoteModel]
    let lastSuccessfulModels: [RemoteModel]

    let onRefresh: () -> Void
    let onRequestKeyEntry: () -> Void

    internal var body: some View {
        VStack(spacing: WelcomeConstants.spacingMedium) {
            providerPicker
            keyStatusSection
            contentSection
        }
    }

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
        .accessibilityLabel(Text(String(localized: "Remote provider", bundle: .module)))
    }

    private var keyStatusSection: some View {
        HStack(spacing: WelcomeConstants.spacingMedium) {
            keyStatusLabel
            Spacer()
            keyStatusButton
        }
    }

    private var keyStatusLabel: some View {
        Group {
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
        }
    }

    private var keyStatusButton: some View {
        Button(action: onRequestKeyEntry) {
            Text(isKeyConfigured ? "Update Key" : "Add Key", bundle: .module)
        }
        .buttonStyle(.bordered)
    }

    @ViewBuilder private var contentSection: some View {
        if !isKeyConfigured {
            keyRequiredView
        } else {
            WelcomeRemoteModelsModelsPanel(
                selectedModel: $selectedModel,
                searchText: $searchText,
                isLoading: isLoading,
                errorMessage: errorMessage,
                models: models,
                lastSuccessfulModels: lastSuccessfulModels,
                onRefresh: onRefresh
            )
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
            Button(action: onRequestKeyEntry) {
                Text("Add API Key", bundle: .module)
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, alignment: .center)
    }
}
