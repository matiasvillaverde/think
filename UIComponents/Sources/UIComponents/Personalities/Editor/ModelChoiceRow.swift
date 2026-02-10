import SwiftUI

internal struct ModelChoiceRow: View {
    private enum Layout {
        static let spacing: CGFloat = 12
        static let iconSize: CGFloat = 42
        static let iconCornerRadius: CGFloat = 12
        static let titleSubtitleSpacing: CGFloat = 3
        static let metadataSpacing: CGFloat = 8
        static let paddingV: CGFloat = 10
        static let paddingH: CGFloat = 12
        static let cornerRadius: CGFloat = 14
        static let strokeOpacity: Double = 0.14
        static let strokeWidth: CGFloat = 1
        static let statusPillPaddingH: CGFloat = 8
        static let statusPillPaddingV: CGFloat = 3
        static let statusPillOpacity: Double = 0.12
    }

    let title: String
    let subtitle: String
    let icon: AnyView
    let isSelected: Bool
    let statusPill: String?
    let onTap: () -> Void

    internal var body: some View {
        Button(action: onTap) { rowContent }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
    }

    private var rowContent: some View {
        HStack(spacing: Layout.spacing) {
            icon
                .frame(width: Layout.iconSize, height: Layout.iconSize)
                .clipShape(RoundedRectangle(cornerRadius: Layout.iconCornerRadius))
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: Layout.titleSubtitleSpacing) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(Color.textPrimary)
                    .lineLimit(1)

                HStack(spacing: Layout.metadataSpacing) {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(Color.textSecondary)
                        .lineLimit(1)

                    if let statusPill {
                        Text(statusPill)
                            .font(.caption2)
                            .fontWeight(.semibold)
                            .foregroundStyle(Color.paletteOrange)
                            .padding(.horizontal, Layout.statusPillPaddingH)
                            .padding(.vertical, Layout.statusPillPaddingV)
                            .background(Color.paletteOrange.opacity(Layout.statusPillOpacity))
                            .clipShape(Capsule())
                    }
                }
            }

            Spacer(minLength: 0)
            selectionIndicator
        }
        .padding(.vertical, Layout.paddingV)
        .padding(.horizontal, Layout.paddingH)
        .background(Color.backgroundSecondary)
        .overlay(
            RoundedRectangle(cornerRadius: Layout.cornerRadius)
                .stroke(
                    Color.textSecondary.opacity(Layout.strokeOpacity),
                    lineWidth: Layout.strokeWidth
                )
        )
        .clipShape(RoundedRectangle(cornerRadius: Layout.cornerRadius))
    }

    private var selectionIndicator: some View {
        Group {
            if isSelected {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(Color.paletteGreen)
                    .accessibilityHidden(true)
            } else {
                Image(systemName: "circle")
                    .foregroundStyle(Color.textSecondary)
                    .accessibilityHidden(true)
            }
        }
        .font(.title3)
    }
}
