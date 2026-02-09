import SwiftUI

internal struct WelcomeHeaderSection: View {
    private enum Layout {
        static let shadowOpacity: Double = 0.18
        static let shadowRadius: CGFloat = 16
    }

    var body: some View {
        VStack(spacing: WelcomeConstants.spacingMedium) {
            Image(ImageResource(name: "openclaw-ghost", bundle: .module))
                .resizable()
                .scaledToFit()
                .frame(
                    width: WelcomeConstants.iconSizeLarge,
                    height: WelcomeConstants.iconSizeLarge
                )
                .shadow(
                    color: .marketingPrimary.opacity(Layout.shadowOpacity),
                    radius: Layout.shadowRadius
                )
                .accessibilityHidden(true)

            Text("Welcome to Think", bundle: .module)
                .font(.largeTitle)
                .bold()
                .foregroundColor(.textPrimary)

            Text(
                """
                Choose how you want to run OpenClaw: fully local, remote APIs,
                or connect an OpenClaw Gateway.
                """,
                bundle: .module
            )
            .font(.title3)
            .foregroundColor(.textSecondary)
            .multilineTextAlignment(.center)
            .frame(maxWidth: WelcomeConstants.maxTextWidth)
        }
        .padding(.top, WelcomeConstants.topPadding)
    }
}

#if DEBUG
#Preview {
    WelcomeHeaderSection()
        .padding()
}
#endif
