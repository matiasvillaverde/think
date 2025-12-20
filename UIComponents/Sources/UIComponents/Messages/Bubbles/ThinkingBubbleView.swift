import Database
import SwiftUI

// MARK: - ThinkingBubbleView

public struct ThinkingBubbleView: View {
    @Bindable var message: Message
    @Binding var showingThinkingView: Bool

    public var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: MessageLayout.spacing) {
                reasoningView
            }
            Spacer()
        }
    }

    private var reasoningView: some View {
        ReasoningView(message: message)
            .font(.body)
            .foregroundColor(.textPrimary)
            .padding(MessageLayout.bubblePadding)
            .background(Color.backgroundSecondary)
            .cornerRadius(MessageLayout.cornerRadius)
            .onTapGesture {
                showingThinkingView.toggle()
            }
            .accessibilityAddTraits(.isButton)
            .accessibilityLabel(
                String(
                    localized: "View full thinking process",
                    bundle: .module,
                    comment: """
                    Accessibility label for the button
                    that allows the user to view the full thinking process
                    """
                )
            )
    }
}

// MARK: - Preview

#if DEBUG
    #Preview {
        @Previewable @State var message: Message = Message.previewWithThinking
        @Previewable @State var showingThinkingView: Bool = false
        ThinkingBubbleView(
            message: message,
            showingThinkingView: $showingThinkingView
        )
    }
#endif
