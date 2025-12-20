import Abstractions
import Database
import SwiftUI

// MARK: - Stop Generation Button

internal struct StopGenerationButton: View {
    @Environment(\.generator)
    var viewModel: ViewModelGenerating

    @Bindable var chat: Chat

    var body: some View {
        CircleIconButton(
            systemName: "stop.circle.fill",
            color: Color.iconAlert,
            keyboardShortcut: .cancelAction
        ) {
            Task(priority: .userInitiated) {
                await viewModel.stop()
            }
        }
        .help(
            String(
                localized: "Stop generation of AI message",
                bundle: .module,
                comment: "Tooltip for the stop generation button in the chat view"
            )
        )
        .keyboardShortcut(.escape)
    }
}

// MARK: - Preview

#if DEBUG
    #Preview {
        @Previewable @State var chat: Chat = .preview
        HStack {
            StopGenerationButton(chat: chat)
            SendButton {
                print("Sent!")
            }
        }
    }
#endif
