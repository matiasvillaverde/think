import Database
import SwiftUI

internal struct FullReasoningView: View {
    // MARK: - Constants

    private enum Constants {
        static let macWindowMinWidth: CGFloat = 600
        static let macWindowMinHeight: CGFloat = 400
        static let iconSize: CGFloat = 20
    }

    @Bindable var message: Message
    @Binding var showingFullThinkingView: Bool

    var body: some View {
        platformSpecificView()
    }

    @ViewBuilder
    private func platformSpecificView() -> some View {
        #if os(iOS) || os(visionOS)
            NavigationView {
                contentView()
            }
        #else
            contentView()
        #endif
    }

    @ViewBuilder
    private func contentView() -> some View {
        ScrollView {
            Text(message.thinking ?? "")
                .font(.body)
                .foregroundColor(Color.textPrimary)
                .padding()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(Color.backgroundPrimary.ignoresSafeArea())
        #if os(iOS) || os(visionOS)
            .navigationBarTitle(
                String(
                    localized: "Reasoning Process",
                    bundle: .module,
                    comment: "Title for the view showing the reasoning process"
                ),
                displayMode: .inline
            )
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: close) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(Color.iconPrimary)
                            .accessibilityLabel(
                                "Close window"
                            )
                    }
                }
            }
        #elseif os(macOS)
            .frame(minWidth: Constants.macWindowMinWidth, minHeight: Constants.macWindowMinHeight)
            .toolbar {
                ToolbarItem(placement: .automatic) {
                    Button(action: close) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(Color.iconPrimary)
                            .accessibilityLabel("Close window")
                    }
                }
            }
        #endif
            .help(
                String(
                    localized: "Reasoning process to find a better answer",
                    bundle: .module,
                    comment: "Help text for the full reasoning view"
                )
            )
    }

    private func close() {
        showingFullThinkingView = false
    }
}

// MARK: - Preview

#if DEBUG
    #Preview {
        @Previewable @State var message: Message = .previewWithThinking
        @Previewable @State var showingFullThinkingView: Bool = true

        FullReasoningView(message: message, showingFullThinkingView: $showingFullThinkingView)
            // Note: thinking is now computed from channels, can't be directly modified
            // .task {
            //     for _ in 0 ..< 100 {
            //         message.thinking = "Lorem ipsum dolor sit amet " + (message.thinking ?? "")
            //     }
            // }
    }
#endif
