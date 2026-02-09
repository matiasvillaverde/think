import SwiftUI

/// A styled OpenClaw setup surface intended for onboarding and the model setup flow.
///
/// This wraps `OpenClawSettingsView` but adds a lightweight, minimal "hero" header so
/// the screen reads as a first-class setup step instead of a settings form.
public struct OpenClawSetupView: View {
    private enum Layout {
        static let heroHeight: CGFloat = 180
        static let heroCornerRadius: CGFloat = 18
        static let heroStrokeOpacity: Double = 0.18
        static let heroImageSize: CGFloat = 72
        static let heroTitleSpacing: CGFloat = 6
        static let contentSpacing: CGFloat = 18
        static let contentPadding: CGFloat = 16
        static let heroArtworkWidth: CGFloat = 220
        static let heroArtworkOpacity: Double = 0.28
        static let heroGradientPrimaryOpacity: Double = 0.22
        static let heroGradientSecondaryOpacity: Double = 0.18
        static let heroGradientBackgroundOpacity: Double = 0.9
        static let heroHStackSpacing: CGFloat = 14
        static let heroPadding: CGFloat = 18
        static let heroSubtitleLineLimit: Int = 3
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Layout.contentSpacing) {
                hero
                OpenClawSettingsView()
            }
            .padding(Layout.contentPadding)
        }
        .background(OpenClawBackground())
    }

    private var hero: some View {
        ZStack {
            heroBackground
            heroContent
        }
        .frame(height: Layout.heroHeight)
    }

    private var heroBackground: some View {
        RoundedRectangle(cornerRadius: Layout.heroCornerRadius)
            .fill(
                LinearGradient(
                    colors: [
                        Color.marketingPrimary.opacity(Layout.heroGradientPrimaryOpacity),
                        Color.marketingSecondary.opacity(Layout.heroGradientSecondaryOpacity),
                        Color.backgroundSecondary.opacity(Layout.heroGradientBackgroundOpacity)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay(
                RoundedRectangle(cornerRadius: Layout.heroCornerRadius)
                    .stroke(Color.textSecondary.opacity(Layout.heroStrokeOpacity), lineWidth: 1)
            )
            .overlay(alignment: .trailing) { heroArtwork }
    }

    private var heroContent: some View {
        HStack(spacing: Layout.heroHStackSpacing) {
            Image(ImageResource(name: "openclaw-ghost", bundle: .module))
                .resizable()
                .scaledToFit()
                .frame(width: Layout.heroImageSize, height: Layout.heroImageSize)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: Layout.heroTitleSpacing) {
                Text("Connect OpenClaw", bundle: .module)
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundStyle(Color.textPrimary)

                Text(
                    "Pair Think with a remote OpenClaw Gateway for OpenClaw-style workflows.",
                    bundle: .module
                )
                .font(.callout)
                .foregroundStyle(Color.textSecondary)
                .lineLimit(Layout.heroSubtitleLineLimit)
            }

            Spacer(minLength: 0)
        }
        .padding(Layout.heroPadding)
    }

    private var heroArtwork: some View {
        Image(ImageResource(name: "openclaw-hero", bundle: .module))
            .resizable()
            .scaledToFill()
            .frame(width: Layout.heroArtworkWidth, height: Layout.heroHeight)
            .clipped()
            .opacity(Layout.heroArtworkOpacity)
            .accessibilityHidden(true)
            .mask(
                LinearGradient(
                    colors: [Color.paletteClear, Color.paletteBlack],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
    }
}

private struct OpenClawBackground: View {
    private enum Layout {
        static let midStopOpacity: Double = 0.9
    }

    var body: some View {
        LinearGradient(
            colors: [
                Color.backgroundPrimary,
                Color.backgroundSecondary.opacity(Layout.midStopOpacity),
                Color.backgroundPrimary
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
    }
}

#if DEBUG
#Preview {
    OpenClawSetupView()
}
#endif
