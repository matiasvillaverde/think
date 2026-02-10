import Abstractions
import SwiftUI

internal struct RemoteModelsProviderSection: View {
    @Binding var selectedProvider: RemoteProviderType
    let isKeyConfigured: Bool
    let onTapKeyButton: () -> Void

    var body: some View {
        Section {
            Picker(selection: $selectedProvider) {
                ForEach(RemoteProviderType.allCases, id: \.self) { provider in
                    Text(provider.displayName).tag(provider)
                }
            } label: {
                Text("Provider", bundle: .module)
            }
            .pickerStyle(.segmented)

            keyStatusRow
        } footer: {
            Text(
                "Add a provider API key, then pick a model to use in this chat.",
                bundle: .module
            )
            .font(.footnote)
            .foregroundStyle(Color.textSecondary)
        }
    }

    private var keyStatusRow: some View {
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

            Spacer(minLength: 0)

            Button(action: onTapKeyButton) {
                Text(isKeyConfigured ? "Update Key" : "Add Key", bundle: .module)
            }
            .buttonStyle(.bordered)
        }
    }
}
