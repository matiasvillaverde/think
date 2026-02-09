import SwiftUI

/// An empty state view shown when the user has no downloaded or downloading models
internal struct MyModelsEmptyState: View {
    // MARK: - Properties

    @Binding var isDiscoveryPresented: Bool

    #if os(macOS)
        @Environment(\.openWindow)
        private var openWindow: OpenWindowAction
        @Environment(\.dismiss)
        private var dismiss: DismissAction
    #endif

    // MARK: - Initialization

    init(isDiscoveryPresented: Binding<Bool>) {
        _isDiscoveryPresented = isDiscoveryPresented
    }

    init() {
        _isDiscoveryPresented = .constant(false)
    }

    // MARK: - Constants

    private enum Layout {
        static let iconSize: CGFloat = 80
        static let spacing: CGFloat = 24
        static let maxWidth: CGFloat = 300
        static let iconBackgroundMultiplier: CGFloat = 1.5
        static let backgroundOpacity: Double = 0.1
    }

    // MARK: - Body

    var body: some View {
        VStack(spacing: Layout.spacing) {
            Spacer()

            iconView

            titleView

            descriptionView

            hintView

            Spacer()
            Spacer()
        }
        .padding(.horizontal, DesignConstants.Spacing.large)
    }

    // MARK: - Private Views

    private var iconView: some View {
        ZStack {
            Circle()
                .fill(Color.accentColor.opacity(Layout.backgroundOpacity))
                .frame(
                    width: Layout.iconSize * Layout.iconBackgroundMultiplier,
                    height: Layout.iconSize * Layout.iconBackgroundMultiplier
                )

            Image(systemName: "square.stack.3d.down.right")
                .font(.system(size: Layout.iconSize, weight: .light))
                .foregroundColor(.accentColor)
                .symbolRenderingMode(.hierarchical)
                .accessibilityLabel("No models icon")
        }
    }

    private var titleView: some View {
        Text("No Models Yet", bundle: .module)
            .font(.title)
            .fontWeight(.semibold)
            .foregroundColor(.textPrimary)
            .multilineTextAlignment(.center)
    }

    private var descriptionView: some View {
        Text(
            "Start exploring and downloading AI models from the Discover tab.",
            bundle: .module
        )
        .font(.body)
        .foregroundColor(.textSecondary)
        .multilineTextAlignment(.center)
        .frame(maxWidth: Layout.maxWidth)
    }

    private var hintView: some View {
        Button {
            discoverAction()
        } label: {
            HStack {
                Image(systemName: "lightbulb.fill")
                    .font(.footnote)
                    .foregroundColor(.orange)
                    .accessibilityLabel("Tip")

                Text("Tip: Explore new models to enhance your experience!", bundle: .module)
                    .font(.footnote)
                    .foregroundColor(.textSecondary)

                Image(systemName: "arrow.right")
                    .accessibilityLabel("Go to discover")
                    .font(.caption2)
                    .foregroundColor(.orange)
            }
            .padding(.horizontal, DesignConstants.Spacing.medium)
            .padding(.vertical, DesignConstants.Spacing.small)
            .background(
                RoundedRectangle(cornerRadius: DesignConstants.Radius.standard)
                    .fill(Color.paletteOrange.opacity(Layout.backgroundOpacity))
            )
        }
        .buttonStyle(.plain)
        .padding(.top, DesignConstants.Spacing.small)
    }

    // MARK: - Actions

    private func discoverAction() {
        #if os(macOS)
            dismiss() // Dismiss the popover first
            let delay: TimeInterval = 0.1
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                openWindow(id: "discovery")
            }
        #else
            // Send notification to switch to Discovery tab
            NotificationCenter.default.post(
                name: Notification.Name("SwitchToDiscoveryTab"),
                object: nil
            )
        #endif
    }
}

// MARK: - Preview

#if DEBUG
    #Preview {
        @Previewable @State var isDiscoveryPresented: Bool = false
        MyModelsEmptyState(isDiscoveryPresented: $isDiscoveryPresented)
            .background(Color.backgroundPrimary)
    }
#endif
