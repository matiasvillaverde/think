import Database
import SwiftUI

// **MARK: - ModelSelectionButton**
public struct ModelSelectionButton: View {
    private enum Layout {
        static let minWidth: CGFloat = 400
        static let minHeight: CGFloat = 500
        static let headerSpacing: CGFloat = 5

        // Tutorial popover layout constants
        static let tutorialPopoverWidth: CGFloat = 250
        static let tutorialStackSpacing: CGFloat = 12
        static let tutorialHeadlineBottomPadding: CGFloat = 4
        static let tutorialCaptionTopPadding: CGFloat = 8
        static let tutorialPopoverLoadDelay: TimeInterval = 10
        static let lineLimit: Int = 2
        static let minMemory: UInt64 = 6_214_444_736
    }

    // For the tutorial popover
    @AppStorage("hasSeenModelTutorial")
    private var hasSeenModelTutorial: Bool = false

    @State private var isTutorialPopoverPresented: Bool = false

    #if os(macOS)
        @Environment(\.openWindow)
        private var openWindow: OpenWindowAction
    #endif

    let modelText: AttributedString
    @Binding var isPopoverPresented: Bool
    @Bindable var chat: Chat

    public var body: some View {
        Button {
            // When button is tapped, dismiss tutorial and show the model selection
            isTutorialPopoverPresented = false
            hasSeenModelTutorial = true
            isPopoverPresented.toggle()
        } label: {
            HStack(spacing: Layout.headerSpacing) {
                Text(modelText)

                Image(systemName: "chevron.forward")
                    .foregroundStyle(Color.textSecondary)
                    .tint(Color.marketingSecondary)
                    .font(.footnote)
                    .accessibilityLabel(
                        String(
                            localized: "Select Model",
                            bundle: .module,
                            comment: "Accessibility label in the model selection button"
                        )
                    )
            }
        }
        // Tutorial popover that appears once
        .popover(isPresented: $isTutorialPopoverPresented) {
            textView
                .onTapGesture {
                    isTutorialPopoverPresented = false
                    hasSeenModelTutorial = true
                    isPopoverPresented.toggle()
                }
                .accessibilityAddTraits(.isButton)
                .accessibilityLabel(
                    String(
                        localized: "Tutorial popover for model selection button",
                        bundle: .module,
                        comment: "Tutorial popover for model selection button accessibility label"
                    )
                )
                .padding()
                .frame(width: Layout.tutorialPopoverWidth)
                .presentationCompactAdaptation(.popover)
        }
        #if os(macOS)
        .onChange(of: isPopoverPresented) { _, newValue in
            if newValue {
                // Open Discovery window on macOS
                openWindow(id: "discovery")
                isPopoverPresented = false
            }
        }
        #else
        .fullScreenCover(isPresented: $isPopoverPresented) {
            ModelManagementView(chat: chat, isPresented: $isPopoverPresented)
        }
        #endif
        .onAppear {
            // Show the tutorial popover only if it hasn't been seen before
            if !hasSeenModelTutorial, shouldShowTutorial {
                // Slight delay to ensure the view is fully loaded
                DispatchQueue.main
                    .asyncAfter(deadline: .now() + Layout.tutorialPopoverLoadDelay) {
                        isTutorialPopoverPresented = true
                    }
            }
        }
    }

    private var textView: some View {
        VStack(alignment: .center, spacing: Layout.tutorialStackSpacing) {
            Text(
                "Download More Models! ✨",
                bundle: .module,
                comment: "Tutorial headline for model selection button"
            )
            .font(.title3)
            .lineLimit(Layout.lineLimit)
            .fontWeight(.bold)
            .foregroundStyle(Color.textPrimary)
            .padding(.bottom, Layout.tutorialHeadlineBottomPadding)
            Text(
                """
                Tap here to get smarter, more helpful responses for your conversations. \
                100% Open-Source and free
                """,
                bundle: .module,
                comment: "Tutorial text for model selection button"
            )
            .font(.body)
            .foregroundStyle(Color.textPrimary)
        }
    }

    private let minimumLaunchCountForTutorial: Int = 3

    private var shouldShowTutorial: Bool {
        UserDefaults.standard.integer(forKey: "appLaunchCount") >= minimumLaunchCountForTutorial
    }
}

#if DEBUG
    #Preview {
        @Previewable @State var isPopoverPresented: Bool = false
        @Previewable @State var chat: Chat = Chat.preview
        ModelSelectionButton(
            modelText: "Think",
            isPopoverPresented: $isPopoverPresented,
            chat: chat
        )
    }
#endif
