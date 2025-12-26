import SwiftUI

internal struct WelcomeHeaderSection: View {
    var body: some View {
        VStack(spacing: WelcomeConstants.spacingMedium) {
            Image(systemName: "sparkles")
                .font(.system(size: WelcomeConstants.iconSizeLarge))
                .foregroundStyle(
                    LinearGradient(
                        colors: [.marketingPrimary, .marketingSecondary],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .symbolRenderingMode(.hierarchical)
                .symbolEffect(.bounce, value: UUID())
                .accessibilityHidden(true)

            Text("Welcome to Think", bundle: .module)
                .font(.largeTitle)
                .bold()
                .foregroundColor(.textPrimary)

            Text(
                "Choose a language model to get started with your first chat",
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
