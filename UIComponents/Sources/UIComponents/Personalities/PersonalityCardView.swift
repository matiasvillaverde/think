// PersonalityCardView.swift
import Database
import SwiftUI

/// Card view displaying a single personality with icon and text
internal struct PersonalityCardView: View {
    let personality: Personality

    private enum Layout {
        static let imageSize: CGFloat = 56
        static let imageBackgroundPadding: CGFloat = 5
        static let cardHeight: CGFloat = 160
        static let cornerRadius: CGFloat = 16
        static let shadowRadius: CGFloat = 2
        static let shadowOffset: CGFloat = 1
        static let borderWidth: CGFloat = 1
        static let titleLineLimit: Int = 1
        static let descriptionLineLimit: Int = 3
    }

    private enum Colors {
        static let imageBackgroundOpacity: Double = 0.12
        static let borderOpacity: Double = 0.1
        static let shadowOpacity: Double = 0.08
    }

    var body: some View {
        VStack(spacing: DesignConstants.Spacing.medium) {
            // Image Section - Centered with tint color background
            imageSection

            // Content Section
            contentSection

            Spacer(minLength: 0)
        }
        .padding(DesignConstants.Spacing.medium)
        .frame(maxWidth: .infinity)
        .frame(height: Layout.cardHeight)
        .background(cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: Layout.cornerRadius))
        .shadow(
            color: Color.black.opacity(Colors.shadowOpacity),
            radius: Layout.shadowRadius,
            x: .zero,
            y: Layout.shadowOffset
        )
    }

    // MARK: - View Components

    @ViewBuilder private var imageSection: some View {
        ZStack {
            // Tinted background circle
            Circle()
                .fill(personality.tintColor.opacity(Colors.imageBackgroundOpacity))
                .frame(
                    width: Layout.imageSize + Layout.imageBackgroundPadding,
                    height: Layout.imageSize + Layout.imageBackgroundPadding
                )

            // Image - check for custom image first, then fall back to system image
            if let customImage = personality.customImage,
                let platformImage = dataToPlatformImage(customImage.image) {
                // Custom uploaded image
                Image(platformImage: platformImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: Layout.imageSize, height: Layout.imageSize)
                    .clipShape(Circle())
                    .accessibilityHidden(true)
            } else {
                // System image or default
                Image(personality.imageName ?? "personality_default", bundle: .module)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: Layout.imageSize, height: Layout.imageSize)
                    .clipShape(Circle())
                    .foregroundColor(personality.tintColor)
                    .accessibilityHidden(true)
            }
        }
    }

    @ViewBuilder private var contentSection: some View {
        VStack(spacing: DesignConstants.Spacing.xSmall) {
            // Title
            Text(personality.name)
                .font(.system(.headline, design: .rounded, weight: .semibold))
                .foregroundColor(Color.textPrimary)
                .lineLimit(Layout.titleLineLimit)
                .truncationMode(.tail)
                .multilineTextAlignment(.center)

            // Description
            Text(personality.displayDescription)
                .font(.system(.caption, design: .default, weight: .regular))
                .foregroundColor(Color.textSecondary)
                .lineLimit(Layout.descriptionLineLimit)
                .truncationMode(.tail)
                .multilineTextAlignment(.center)
        }
    }

    @ViewBuilder private var cardBackground: some View {
        RoundedRectangle(cornerRadius: Layout.cornerRadius)
            .fill(Color.backgroundPrimary)
            .overlay(
                RoundedRectangle(cornerRadius: Layout.cornerRadius)
                    .strokeBorder(
                        personality.tintColor.opacity(Colors.borderOpacity),
                        lineWidth: Layout.borderWidth
                    )
            )
    }

    private var accessibilityLabel: String {
        "\(personality.name). \(personality.displayDescription)"
    }

    private var accessibilityHint: String {
        String(localized: "Double tap to select this personality", bundle: .module)
    }
}

// MARK: - Preview

#if DEBUG
    #Preview("Default Personality") {
        PersonalityCardView(personality: .default)
            .padding()
    }

    #Preview("Custom Personality") {
        PersonalityCardView(personality: .previewCustom)
            .padding()
    }

    #Preview("Grid Layout") {
        LazyVGrid(
            columns: Array(repeating: GridItem(.flexible()), count: PreviewConstants.gridColumns),
            spacing: PreviewConstants.gridSpacing
        ) {
            PersonalityCardView(personality: .default)
            PersonalityCardView(personality: .previewCustom)
            PersonalityCardView(personality: .default)
            PersonalityCardView(personality: .previewCustom)
        }
        .padding()
    }

#endif

// MARK: - Preview Constants

private enum PreviewConstants {
    static let gridColumns: Int = 2
    static let gridSpacing: CGFloat = 16
}
