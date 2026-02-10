import SwiftUI

internal struct WelcomeOpenClawSection: View {
    private enum Layout {
        static let cardCornerRadius: CGFloat = 14
        static let cardPadding: CGFloat = 14
        static let cardSpacing: CGFloat = 12
        static let imageSize: CGFloat = 56
        static let buttonSpacing: CGFloat = 10
        static let strokeOpacity: Double = 0.16
        static let headerSpacing: CGFloat = 6
        static let subtitleSpacing: CGFloat = 4
        static let subtitleLineLimit: Int = 2
    }

    let onPickLocal: () -> Void
    let onPickRemote: () -> Void

    @State private var isShowingSetup: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: WelcomeConstants.spacingMedium) {
            header
            connectCard
            actionsRow
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: Layout.headerSpacing) {
            Text("Optional: Connect OpenClaw", bundle: .module)
                .font(.headline)
                .foregroundStyle(Color.textPrimary)

            Text(
                """
                If you run an OpenClaw Gateway elsewhere, pair it here.
                You can still chat locally or with remote models without it.
                """,
                bundle: .module
            )
            .font(.subheadline)
            .foregroundStyle(Color.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var connectCard: some View {
        Button {
            isShowingSetup = true
        } label: {
            connectCardLabel
        }
        .buttonStyle(.plain)
        .sheet(isPresented: $isShowingSetup) {
            NavigationStack {
                OpenClawSetupView()
                    .navigationTitle(String(localized: "OpenClaw", bundle: .module))
                    #if os(iOS)
                    .navigationBarTitleDisplayMode(.inline)
                    #endif
            }
        }
    }

    private var connectCardLabel: some View {
        HStack(alignment: .center, spacing: Layout.cardSpacing) {
            Image(ImageResource(name: "openclaw-claw", bundle: .module))
                .resizable()
                .scaledToFit()
                .frame(width: Layout.imageSize, height: Layout.imageSize)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: Layout.subtitleSpacing) {
                Text("OpenClaw Gateway", bundle: .module)
                    .font(.headline)
                    .foregroundStyle(Color.textPrimary)

                Text(
                    "Add an instance, test connectivity, and choose an active gateway.",
                    bundle: .module
                )
                .font(.footnote)
                .foregroundStyle(Color.textSecondary)
                .lineLimit(Layout.subtitleLineLimit)
            }

            Spacer(minLength: 0)

            Image(systemName: "chevron.right")
                .font(.footnote)
                .foregroundStyle(Color.textSecondary)
                .accessibilityHidden(true)
        }
        .padding(Layout.cardPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.backgroundSecondary)
        .overlay(
            RoundedRectangle(cornerRadius: Layout.cardCornerRadius)
                .stroke(Color.textSecondary.opacity(Layout.strokeOpacity), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: Layout.cardCornerRadius))
    }

    private var actionsRow: some View {
        HStack(spacing: Layout.buttonSpacing) {
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
    WelcomeOpenClawSection(
        onPickLocal: { /* noop */ },
        onPickRemote: { /* noop */ }
    )
        .padding()
        .background(Color.backgroundPrimary)
}
#endif
