import Abstractions
import SwiftUI

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
                    .background(
                        Color.paletteGreen.opacity(RemoteModelsViewConstants.freeBadgeOpacity)
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
            Label {
                Text("Selected", bundle: .module)
            } icon: {
                Image(systemName: "checkmark.circle.fill")
                    .accessibilityHidden(true)
            }
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
