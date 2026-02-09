import Abstractions
import RemoteSession
import SwiftUI

// MARK: - Constants

private enum RowConstants {
    static let spacing: CGFloat = 12
    static let statusSpacing: CGFloat = 4
    static let padding: CGFloat = 12
    static let cornerRadius: CGFloat = 12
    static let iconSize: CGFloat = 32
    static let menuWidth: CGFloat = 32
    static let hoverOpacity: Double = 0.05
    static let hoverDuration: Double = 0.15
}

// MARK: - Provider Row

/// Row displaying a provider's configuration status with actions.
internal struct APIKeyProviderRow: View {
    let state: ProviderState
    let onConfigure: () -> Void
    let onRemove: () -> Void

    @State private var isHovered: Bool = false

    var body: some View {
        HStack(spacing: RowConstants.spacing) {
            providerIcon
            providerInfo
            Spacer()
            statusIndicator
            actionButton
        }
        .padding(RowConstants.padding)
        .background(backgroundView)
        .contentShape(Rectangle())
        .onHover { hovering in
            withAnimation(.easeInOut(duration: RowConstants.hoverDuration)) {
                isHovered = hovering
            }
        }
    }

    private var providerIcon: some View {
        Image(systemName: providerSystemImage)
            .font(.title2)
            .frame(width: RowConstants.iconSize, height: RowConstants.iconSize)
            .foregroundStyle(Color.textPrimary)
            .accessibilityLabel(
                Text(
                    "\(state.provider.displayName) icon",
                    bundle: .module
                )
            )
    }

    private var providerSystemImage: String {
        switch state.provider {
        case .openRouter:
            return "arrow.triangle.branch"

        case .openAI:
            return "brain"

        case .anthropic:
            return "sparkle"

        case .google:
            return "g.circle"
        }
    }

    private var providerInfo: some View {
        VStack(alignment: .leading, spacing: RowConstants.statusSpacing) {
            Text(state.provider.displayName)
                .font(.headline)

            Text(state.provider.description)
                .font(.caption)
                .foregroundStyle(Color.textSecondary)
                .lineLimit(1)
        }
    }

    @ViewBuilder private var statusIndicator: some View {
        if state.isConfigured {
            Label {
                Text(
                    String(
                        localized: "Configured",
                        bundle: .module,
                        comment: "Status label for configured API key"
                    )
                )
            } icon: {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                    .accessibilityHidden(true)
            }
            .font(.caption)
            .foregroundStyle(Color.textSecondary)
        }
    }

    private var actionButton: some View {
        Group {
            if state.isConfigured {
                configuredMenu
            } else {
                configureButton
            }
        }
    }

    private var configuredMenu: some View {
        Menu {
            Button {
                onConfigure()
            } label: {
                Label(
                    String(
                        localized: "Update Key",
                        bundle: .module,
                        comment: "Button to update API key"
                    ),
                    systemImage: "pencil"
                )
            }

            Button(role: .destructive) {
                onRemove()
            } label: {
                Label(
                    String(
                        localized: "Remove Key",
                        bundle: .module,
                        comment: "Button to remove API key"
                    ),
                    systemImage: "trash"
                )
            }
        } label: {
            Image(systemName: "ellipsis.circle")
                .font(.title3)
                .foregroundStyle(Color.textSecondary)
                .accessibilityLabel(
                    Text(
                        "More options",
                        bundle: .module
                    )
                )
        }
        .menuStyle(.borderlessButton)
        .frame(width: RowConstants.menuWidth)
    }

    private var configureButton: some View {
        Button {
            onConfigure()
        } label: {
            Text(
                String(
                    localized: "Configure",
                    bundle: .module,
                    comment: "Button to configure API key"
                )
            )
            .font(.subheadline.weight(.medium))
        }
        .buttonStyle(.borderedProminent)
    }

    private var backgroundView: some View {
        RoundedRectangle(cornerRadius: RowConstants.cornerRadius)
            .fill(
                isHovered
                    ? Color.textPrimary.opacity(RowConstants.hoverOpacity)
                    : Color.paletteClear
            )
    }
}

// MARK: - Provider State

internal struct ProviderState: Identifiable {
    let provider: RemoteProviderType
    var isConfigured: Bool = false

    var id: String { provider.rawValue }
}
