import SwiftUI

/// Card view for creating a new personality
internal struct CreatePersonalityCardView: View {
    let action: () -> Void

    private enum Layout {
        static let imageSize: CGFloat = 56
        static let imageBackgroundPadding: CGFloat = 5
        static let cardHeight: CGFloat = 160
        static let cornerRadius: CGFloat = 16
        static let shadowRadius: CGFloat = 2
        static let shadowOffset: CGFloat = 1
        static let borderWidth: CGFloat = 1
        static let dashLineLength: CGFloat = 8
        static let dashGapLength: CGFloat = 4
        static let dashPattern: [CGFloat] = [dashLineLength, dashGapLength]
    }

    private enum Colors {
        static let imageBackgroundOpacity: Double = 0.12
        static let borderOpacity: Double = 0.3
        static let shadowOpacity: Double = 0.08
        static let descriptionOpacity: Double = 0.8
    }

    private enum Proportions {
        static let iconScale: CGFloat = 0.7
    }

    var body: some View {
        Button(action: action) {
            VStack(spacing: DesignConstants.Spacing.medium) {
                // Plus icon
                imageSection

                // Content
                contentSection

                Spacer(minLength: 0)
            }
            .padding(DesignConstants.Spacing.medium)
            .frame(maxWidth: .infinity)
            .frame(height: Layout.cardHeight)
            .background(cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: Layout.cornerRadius))
            .shadow(
                color: Color.paletteBlack.opacity(Colors.shadowOpacity),
                radius: Layout.shadowRadius,
                x: .zero,
                y: Layout.shadowOffset
            )
        }
        .buttonStyle(PlainButtonStyle())
    }

    // MARK: - View Components

    @ViewBuilder private var imageSection: some View {
        ZStack {
            // Background circle with dashed border
            Circle()
                .strokeBorder(
                    style: StrokeStyle(
                        lineWidth: Layout.borderWidth,
                        dash: Layout.dashPattern
                    )
                )
                .foregroundColor(Color.accentColor.opacity(Colors.borderOpacity))
                .frame(
                    width: Layout.imageSize + Layout.imageBackgroundPadding,
                    height: Layout.imageSize + Layout.imageBackgroundPadding
                )

            // Plus icon
            Image(systemName: "plus.circle.fill")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(
                    width: Layout.imageSize * Proportions.iconScale,
                    height: Layout.imageSize * Proportions.iconScale
                )
                .foregroundColor(Color.accentColor)
                .accessibilityHidden(true)
        }
    }

    @ViewBuilder private var contentSection: some View {
        VStack(spacing: DesignConstants.Spacing.xSmall) {
            // Title
            Text("Create Your Own", bundle: .module)
                .font(.system(.headline, design: .rounded, weight: .semibold))
                .foregroundColor(Color.accentColor)
                .multilineTextAlignment(.center)

            // Description
            Text("AI Personality", bundle: .module)
                .font(.system(.caption, design: .default, weight: .regular))
                .foregroundColor(Color.accentColor.opacity(Colors.descriptionOpacity))
                .multilineTextAlignment(.center)
        }
    }

    @ViewBuilder private var cardBackground: some View {
        RoundedRectangle(cornerRadius: Layout.cornerRadius)
            .fill(Color.backgroundSecondary)
            .overlay(
                RoundedRectangle(cornerRadius: Layout.cornerRadius)
                    .strokeBorder(
                        style: StrokeStyle(
                            lineWidth: Layout.borderWidth,
                            dash: Layout.dashPattern
                        )
                    )
                    .foregroundColor(Color.accentColor.opacity(Colors.borderOpacity))
            )
    }
}

// MARK: - Preview

#if DEBUG
    #Preview("Create Card") {
        CreatePersonalityCardView {
            // no-op
        }
        .padding()
        .frame(width: 200)
    }

    #Preview("Grid with Create") {
        LazyVGrid(
            columns: Array(repeating: GridItem(.flexible()), count: 2),
            spacing: 16
        ) {
            CreatePersonalityCardView {
                // no-op
            }
            PersonalityCardView(personality: .default)
            PersonalityCardView(personality: .previewCustom)
        }
        .padding()
    }
#endif
