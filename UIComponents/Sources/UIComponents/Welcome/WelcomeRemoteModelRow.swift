import Abstractions
import SwiftUI

internal struct WelcomeRemoteModelRow: View {
    let model: RemoteModel
    let isSelected: Bool
    let onSelect: () -> Void

    internal var body: some View {
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
