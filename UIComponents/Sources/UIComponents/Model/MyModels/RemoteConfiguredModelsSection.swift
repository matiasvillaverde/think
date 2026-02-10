import Abstractions
import Database
import SwiftUI

internal struct RemoteConfiguredModelsSection: View {
    let models: [Model]
    @Bindable var chat: Chat
    let providerKeyStatus: [RemoteProviderType: Bool]
    let onSelect: (Model) -> Void
    let onDelete: (Model) -> Void
    let onAddKey: (RemoteProviderType) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: DesignConstants.Spacing.medium) {
            header
            LazyVStack(spacing: DesignConstants.Spacing.standard) {
                ForEach(models, id: \.id) { model in
                    RemoteConfiguredModelRow(
                        model: model,
                        isSelected: isSelected(model),
                        isKeyConfigured: isKeyConfigured(for: model),
                        provider: provider(for: model),
                        onSelect: { onSelect(model) },
                        onDelete: { onDelete(model) },
                        onAddKey: { provider in onAddKey(provider) }
                    )
                }
            }
        }
    }

    private var header: some View {
        HStack {
            Image(systemName: "globe")
                .foregroundStyle(Color.marketingSecondary)
                .accessibilityHidden(true)

            Text("Remote Models", bundle: .module)
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundColor(.textPrimary)

            Spacer()

            Text("\(models.count)", bundle: .module)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(.textSecondary)
                .padding(.horizontal, DesignConstants.Spacing.small)
                .padding(.vertical, DesignConstants.Spacing.xSmall)
                .background(
                    Capsule()
                        .fill(Color.backgroundSecondary)
                )
        }
        .padding(.horizontal, DesignConstants.Spacing.small)
    }

    private func provider(for model: Model) -> RemoteProviderType? {
        RemoteProviderType.fromRemoteLocation(model.locationHuggingface ?? "")
    }

    private func isKeyConfigured(for model: Model) -> Bool {
        guard let provider = provider(for: model) else {
            return true
        }
        return providerKeyStatus[provider] ?? false
    }

    private func isSelected(_ model: Model) -> Bool {
        model == chat.languageModel || model == chat.imageModel
    }
}
