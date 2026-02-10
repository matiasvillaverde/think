import SwiftUI

internal struct WelcomeOneClickSetupSection: View {
    private enum Layout {
        static let cardCornerRadius: CGFloat = 14
        static let cardPadding: CGFloat = 14
        static let cardSpacing: CGFloat = 12
        static let imageSize: CGFloat = 56
        static let strokeOpacity: Double = 0.16
        static let headerSpacing: CGFloat = 6
        static let subtitleSpacing: CGFloat = 4
        static let subtitleLineLimit: Int = 3
        static let actionsSpacing: CGFloat = 10
        static let priceFontSize: CGFloat = 22
        static let boltIconFontSize: CGFloat = 22
        static let iconCornerRadius: CGFloat = 14
        static let iconBackgroundOpacity: Double = 0.10
        static let badgePaddingH: CGFloat = 10
        static let badgePaddingV: CGFloat = 4
        static let badgeOpacity: Double = 0.14
    }

    let onPickLocal: () -> Void
    let onPickRemote: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: WelcomeConstants.spacingMedium) {
            header
            comingSoonCard
            actionsRow
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: Layout.headerSpacing) {
            Text("One‑Click Setup", bundle: .module)
                .font(.headline)
                .foregroundStyle(Color.textPrimary)

            Text(
                "A hosted, always‑ready setup with zero downloads. Coming soon.",
                bundle: .module
            )
            .font(.subheadline)
            .foregroundStyle(Color.textSecondary)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var comingSoonCard: some View {
        HStack(alignment: .center, spacing: Layout.cardSpacing) {
            boltIcon

            VStack(alignment: .leading, spacing: Layout.subtitleSpacing) {
                priceRow
                descriptionText
            }

            Spacer(minLength: 0)
        }
        .padding(Layout.cardPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.backgroundSecondary)
        .overlay(
            RoundedRectangle(cornerRadius: Layout.cardCornerRadius)
                .stroke(Color.textSecondary.opacity(Layout.strokeOpacity), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: Layout.cardCornerRadius))
        .accessibilityElement(children: .combine)
    }

    private var boltIcon: some View {
        Image(systemName: "bolt.fill")
            .font(.system(size: Layout.boltIconFontSize, weight: .semibold))
            .foregroundStyle(Color.marketingPrimary)
            .frame(width: Layout.imageSize, height: Layout.imageSize)
            .background(Color.marketingPrimary.opacity(Layout.iconBackgroundOpacity))
            .clipShape(RoundedRectangle(cornerRadius: Layout.iconCornerRadius))
            .accessibilityHidden(true)
    }

    private var priceRow: some View {
        HStack(spacing: WelcomeConstants.spacingSmall) {
            Text("$50", bundle: .module)
                .font(.system(
                    size: Layout.priceFontSize,
                    weight: .semibold,
                    design: .rounded
                ))
                .foregroundStyle(Color.textPrimary)

            Text("/ month", bundle: .module)
                .font(.callout)
                .foregroundStyle(Color.textSecondary)

            Text("Coming Soon", bundle: .module)
                .font(.caption2)
                .fontWeight(.semibold)
                .padding(.horizontal, Layout.badgePaddingH)
                .padding(.vertical, Layout.badgePaddingV)
                .background(Color.paletteOrange.opacity(Layout.badgeOpacity))
                .foregroundStyle(Color.paletteOrange)
                .clipShape(Capsule())
        }
    }

    private var descriptionText: some View {
        Text(
            """
            Ideal if you want instant access on every device without managing models or API keys.
            """,
            bundle: .module
        )
        .font(.footnote)
        .foregroundStyle(Color.textSecondary)
        .lineLimit(Layout.subtitleLineLimit)
    }

    private var actionsRow: some View {
        HStack(spacing: Layout.actionsSpacing) {
            Button {
                onPickLocal()
            } label: {
                Text("Pick a Local Model", bundle: .module)
            }
            .buttonStyle(.bordered)

            Button {
                onPickRemote()
            } label: {
                Text("Pick a Remote Model", bundle: .module)
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

#if DEBUG
#Preview {
    WelcomeOneClickSetupSection(onPickLocal: { /* noop */ }, onPickRemote: { /* noop */ })
        .padding()
        .background(Color.backgroundPrimary)
}
#endif
