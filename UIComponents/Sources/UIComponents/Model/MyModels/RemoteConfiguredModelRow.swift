import Abstractions
import Database
import SwiftUI

internal struct RemoteConfiguredModelRow: View {
    let model: Model
    let isSelected: Bool
    let isKeyConfigured: Bool
    let provider: RemoteProviderType?

    let onSelect: () -> Void
    let onDelete: () -> Void
    let onAddKey: (RemoteProviderType) -> Void

    private enum Layout {
        static let iconSize: CGFloat = 40
        static let cornerRadius: CGFloat = 16
        static let strokeOpacity: Double = 0.18
        static let innerPadding: CGFloat = 14
        static let hStackSpacing: CGFloat = 12
        static let vStackSpacing: CGFloat = 4
        static let tagPaddingH: CGFloat = 8
        static let tagPaddingV: CGFloat = 3
        static let tagBackgroundOpacity: Double = 0.12
    }

    var body: some View {
        Button(action: onSelect) {
            content
        }
        .buttonStyle(.plain)
        .disabled(!isKeyConfigured)
        .contextMenu {
            Button(role: .destructive) {
                onDelete()
            } label: {
                Label {
                    Text("Remove", bundle: .module)
                } icon: {
                    Image(systemName: "trash")
                        .accessibilityHidden(true)
                }
            }
        }
    }

    private var content: some View {
        HStack(spacing: Layout.hStackSpacing) {
            providerIcon

            VStack(alignment: .leading, spacing: Layout.vStackSpacing) {
                HStack(spacing: DesignConstants.Spacing.small) {
                    Text(model.displayName)
                        .font(.headline)
                        .foregroundStyle(Color.textPrimary)
                        .lineLimit(1)

                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(Color.paletteGreen)
                            .accessibilityHidden(true)
                    }

                    Spacer(minLength: 0)
                }

                subtitle
            }

            if !isKeyConfigured, let provider {
                Button {
                    onAddKey(provider)
                } label: {
                    Text("Add Key", bundle: .module)
                }
                .buttonStyle(.bordered)
            }
        }
        .padding(Layout.innerPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: Layout.cornerRadius))
        .overlay(
            RoundedRectangle(cornerRadius: Layout.cornerRadius)
                .stroke(Color.textSecondary.opacity(Layout.strokeOpacity), lineWidth: 1)
        )
    }

    @ViewBuilder private var providerIcon: some View {
        Group {
            if let provider {
                Image(provider.assetName, bundle: .module)
                    .resizable()
                    .scaledToFill()
                    .accessibilityLabel(Text("\(provider.displayName) logo", bundle: .module))
            } else {
                RoundedRectangle(cornerRadius: DesignConstants.Radius.small)
                    .fill(Color.textSecondary.opacity(DesignConstants.Opacity.backgroundSubtle))
                    .overlay(
                        Image(systemName: "questionmark")
                            .foregroundStyle(Color.textSecondary)
                            .accessibilityHidden(true)
                    )
            }
        }
        .frame(width: Layout.iconSize, height: Layout.iconSize)
        .clipShape(RoundedRectangle(cornerRadius: DesignConstants.Radius.small))
    }

    @ViewBuilder private var subtitle: some View {
        HStack(spacing: DesignConstants.Spacing.small) {
            if let provider {
                Text(provider.displayName)
                    .font(.caption)
                    .foregroundStyle(Color.textSecondary)
            }

            if !isKeyConfigured {
                Text("Key required", bundle: .module)
                    .font(.caption2)
                    .foregroundStyle(Color.paletteOrange)
                    .padding(.horizontal, Layout.tagPaddingH)
                    .padding(.vertical, Layout.tagPaddingV)
                    .background(Color.paletteOrange.opacity(Layout.tagBackgroundOpacity))
                    .clipShape(Capsule())
            }
        }
    }
}
