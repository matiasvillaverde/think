import Abstractions
import Database
import SwiftData
import SwiftUI

// MARK: - Message Input View

internal struct MessageInputView: View {
    @Environment(\.generator)
    var viewModel: ViewModelGenerating

    @Environment(\.controller)
    private var controller: ViewInteractionController

    @FocusState private var inputIsFocused: Bool
    @State private var inputMessage: String = ""
    @State private var selectedAction: Action = .textGeneration([])

    let overrideCanSend: Bool

    @Bindable private var chat: Chat

    // MARK: - Constants

    enum Constants: Sendable {
        static let vStackSpacing: CGFloat = 8
        static let hStackSpacing: CGFloat = 12
        static let horizontalPadding: CGFloat = 10
        static let shadowOpacity: CGFloat = 0.08
        static let shadowRadius: CGFloat = 8
        static let shadowOffsetX: CGFloat = 0
        static let shadowOffsetY: CGFloat = -3
        static let minHeight: CGFloat = 44
    }

    init(
        chat: Chat,
        overrideCanSend: Bool = false,
        overrideShouldReason: Bool = false,
        overrideShouldDraw: Bool = false
    ) {
        self.chat = chat
        self.overrideCanSend = overrideCanSend

        // Handle override parameters for backward compatibility
        if overrideShouldReason {
            _selectedAction = .init(initialValue: .textGeneration([.reasoning]))
        } else if overrideShouldDraw {
            _selectedAction = .init(initialValue: .imageGeneration([]))
        }
    }

    var body: some View {
        VStack(spacing: Constants.vStackSpacing) {
            chatInputField
        }
    }

    // MARK: - Private View Components

    private var chatInputField: some View {
        ChatField(
            "",
            text: $inputMessage
        ) {
            send()
        } footer: {
            createInputFooter()
        }
        .tint(Color.iconPrimary)
        .textFieldStyle(.plain)
        .focused($inputIsFocused)
        .messageInputStyle()
        .onAppear(perform: handleOnAppear)
        .disabled(isDisabled())
        .applyShadow()
        .task {
            controller.focus = focus
            controller.removeFocus = removeFocus
        }
    }

    private func createInputFooter() -> some View {
        InputFooter(
            chat: chat,
            selectedAction: $selectedAction,
            canStop: canStop,
            canSend: canSend,
            onSend: send
        )
    }

    private func handleOnAppear() {
        if chat.languageModel.state?.isDownloading == true {
            return
        }
        focus()
    }

    // MARK: - Helper Methods

    private func canSend() -> Bool {
        if overrideCanSend {
            return true // For screenshots purposes
        }

        return MessageInputValidator.canSend(
            message: inputMessage,
            chat: chat
        )
    }

    private func canStop() -> Bool {
        MessageInputValidator.canStop(chat: chat)
    }

    private func isDisabled() -> Bool {
        MessageInputValidator.isDisabled(chat: chat)
    }

    private func removeFocus() {
        inputIsFocused = false
    }

    private func focus() {
        inputIsFocused = true
    }

    private func send() {
        guard canSend() else {
            return
        }
        let prompt: String = inputMessage
        inputMessage = ""
        #if os(iOS)
            removeFocus()
        #endif
        empty()
        Task.detached(priority: .userInitiated) {
            await viewModel.generate(
                prompt: prompt,
                overrideAction: selectedAction
            )
        }
    }

    private func empty() {
        guard inputMessage.isEmpty else {
            return
        }
        inputMessage = ""
    }
}

// MARK: - Preview

#if DEBUG
    #Preview(traits: .modifier(PreviewDatabase())) {
        @Previewable @State var chat: Chat = .preview
        MessageInputView(chat: chat)
    }
#endif
