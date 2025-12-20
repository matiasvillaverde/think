import Abstractions
import Kingfisher
import SwiftUI

// MARK: - View Components

extension DiscoveryModelCard {
    var imagePlaceholder: some View {
        ZStack {
            LinearGradient(
                gradient: Gradient(colors: [
                    Color.backgroundPrimary,
                    Color.backgroundSecondary.opacity(DiscoveryConstants.Opacity.placeholder)
                ]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            Image(systemName: "photo")
                .font(.system(
                    size: DiscoveryConstants.FontSize.icon,
                    weight: .light,
                    design: .rounded
                ))
                .foregroundColor(.textSecondary.opacity(DiscoveryConstants.Opacity.medium))
                .accessibilityHidden(true)
        }
        .transition(.opacity.combined(with: .scale(scale: DesignConstants.Scale.transition)))
    }

    var imageErrorView: some View {
        ZStack {
            LinearGradient(
                gradient: Gradient(colors: [
                    Color.red.opacity(DiscoveryConstants.Opacity.extraLight),
                    Color.backgroundPrimary
                ]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            Image(systemName: "photo.badge.exclamationmark")
                .font(.system(
                    size: DiscoveryConstants.FontSize.icon,
                    weight: .light,
                    design: .rounded
                ))
                .foregroundColor(.red.opacity(DiscoveryConstants.Opacity.placeholder))
                .accessibilityHidden(true)
        }
        .transition(.opacity)
    }

    var imageOverlay: some View {
        RoundedRectangle(cornerRadius: DesignConstants.Radius.standard, style: .continuous)
            .strokeBorder(
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color.white.opacity(DesignConstants.Opacity.trackBackground),
                        Color.clear
                    ]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                lineWidth: 1
            )
    }

    func statsView(icon: String, value: String) -> some View {
        HStack(spacing: DesignConstants.Spacing.small) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundColor(.textSecondary)
                .accessibilityHidden(true)

            Text(value)
                .font(.caption)
                .foregroundColor(.textSecondary)
        }
    }
}
