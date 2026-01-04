import SwiftUI

// MARK: - Send Button

internal struct SendButton: View {
    let onSend: () -> Void

    var body: some View {
        CircleIconButton(
            systemName: "arrow.up.circle.fill",
            color: Color.iconConfirmation,
            keyboardShortcut: .defaultAction
        ) {
            onSend()
        }
        .help(
            String(
                localized: "Send message to the AI assistant",
                bundle: .module,
                comment: "Button label for sending a message"
            )
        )
    }
}

// MARK: - Preview

#Preview {
    SendButton {
        // no-op
    }
}
