import Abstractions
import DataAssets
import SwiftUI

internal struct ModelSelectionCard: View {
    let model: DiscoveredModel
    let isSelected: Bool
    let action: () -> Void

    @State private var isHovered: Bool = false

    var body: some View {
        Button(action: action) {
            cardContent
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            isHovered = hovering
        }
    }

    @ViewBuilder private var cardContent: some View {
        VStack(alignment: .leading, spacing: WelcomeConstants.spacingSmall) {
            headerRow
            statsRow
        }
        .padding()
        .background(cardBackground)
        .scaleEffect(isHovered ? WelcomeConstants.hoverScale : 1.0)
        .animation(.easeInOut(duration: WelcomeConstants.animationDuration), value: isHovered)
    }

    @ViewBuilder private var headerRow: some View {
        HStack {
            Image(systemName: modelIcon)
                .font(.title2)
                .foregroundColor(.marketingSecondary)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: WelcomeConstants.spacingTiny) {
                HStack(spacing: WelcomeConstants.spacingSmall) {
                    Text(model.name)
                        .font(.headline)
                        .foregroundColor(.textPrimary)
                        .lineLimit(1)

                    if let recommendationType = model.recommendationType {
                        recommendedBadge(for: recommendationType)
                    }
                }

                Text("by \(model.author)", bundle: .module)
                    .font(.caption)
                    .foregroundColor(.textSecondary)
            }

            Spacer()

            if isSelected {
                Image(systemName: "checkmark.circle.fill")
                    .font(.title3)
                    .foregroundColor(.marketingPrimary)
                    .accessibilityHidden(true)
            }
        }
    }

    @ViewBuilder private var statsRow: some View {
        HStack(spacing: WelcomeConstants.spacingMedium) {
            // Downloads
            Label {
                Text(formatCount(model.downloads))
                    .font(.caption)
            } icon: {
                Image(systemName: "arrow.down.circle")
                    .font(.caption)
                    .accessibilityHidden(true)
            }
            .foregroundColor(.textSecondary)

            // Likes
            Label {
                Text(formatCount(model.likes))
                    .font(.caption)
            } icon: {
                Image(systemName: "heart")
                    .font(.caption)
                    .accessibilityHidden(true)
            }
            .foregroundColor(.textSecondary)

            // Size
            Label {
                Text(formatBytes(model.totalSize))
                    .font(.caption)
            } icon: {
                Image(systemName: "memorychip")
                    .font(.caption)
                    .accessibilityHidden(true)
            }
            .foregroundColor(.textSecondary)
        }
    }

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: WelcomeConstants.cornerRadius)
            .fill(Color.backgroundSecondary)
            .overlay(
                RoundedRectangle(cornerRadius: WelcomeConstants.cornerRadius)
                    .stroke(
                        isSelected || isHovered ? Color.marketingSecondary : Color.paletteClear,
                        lineWidth: WelcomeConstants.borderWidth
                    )
            )
    }

    private var modelIcon: String {
        switch model.name.lowercased() {
        case let name where name.contains("llama"):
            "llama.fill"

        case let name where name.contains("mistral"):
            "wind"

        case let name where name.contains("gemma"):
            "diamond.fill"

        case let name where name.contains("phi"):
            "greek.phi.circle.fill"

        case let name where name.contains("qwen"):
            "q.circle.fill"

        default:
            "brain"
        }
    }

    private func formatCount(_ count: Int) -> String {
        if count >= WelcomeConstants.millionDivider {
            return "\(count / WelcomeConstants.millionDivider)M"
        }
        if count >= WelcomeConstants.thousandDivider {
            return "\(count / WelcomeConstants.thousandDivider)K"
        }
        return "\(count)"
    }

    private func formatBytes(_ bytes: Int64) -> String {
        let formatter: ByteCountFormatter = ByteCountFormatter()
        formatter.countStyle = .memory
        formatter.allowsNonnumericFormatting = false
        return formatter.string(fromByteCount: bytes)
    }

    private func recommendedBadge(for type: RecommendedModels.RecommendationType) -> some View {
        HStack(spacing: WelcomeConstants.badgeSpacing) {
            Image(systemName: badgeIcon(for: type))
                .font(.caption2)
                .fontWeight(.medium)
                .accessibilityHidden(true)

            Text(type.displayName)
                .font(.caption2)
                .fontWeight(.medium)
        }
        .padding(.horizontal, WelcomeConstants.badgeHorizontalPadding)
        .padding(.vertical, WelcomeConstants.badgeVerticalPadding)
        .background(
            RoundedRectangle(cornerRadius: WelcomeConstants.badgeCornerRadius)
                .fill(badgeBackgroundColor(for: type))
        )
        .foregroundColor(badgeForegroundColor(for: type))
        .overlay(
            RoundedRectangle(cornerRadius: WelcomeConstants.badgeCornerRadius)
                .stroke(badgeBorderColor(for: type), lineWidth: WelcomeConstants.badgeBorderWidth)
        )
    }

    private func badgeIcon(for type: RecommendedModels.RecommendationType) -> String {
        switch type {
        case .fast:
            "bolt.fill"

        case .complexTasks:
            "brain.head.profile"
        }
    }

    private func badgeBackgroundColor(for type: RecommendedModels.RecommendationType) -> Color {
        switch type {
        case .fast:
            Color.paletteGreen.opacity(WelcomeConstants.badgeOpacity)

        case .complexTasks:
            Color.paletteGreen.opacity(WelcomeConstants.badgeOpacity)
        }
    }

    private func badgeForegroundColor(for type: RecommendedModels.RecommendationType) -> Color {
        switch type {
        case .fast:
            Color.paletteGreen

        case .complexTasks:
            Color.paletteGreen
        }
    }

    private func badgeBorderColor(for type: RecommendedModels.RecommendationType) -> Color {
        switch type {
        case .fast:
            Color.paletteGreen.opacity(WelcomeConstants.badgeBorderOpacity)

        case .complexTasks:
            Color.paletteGreen.opacity(WelcomeConstants.badgeBorderOpacity)
        }
    }
}
