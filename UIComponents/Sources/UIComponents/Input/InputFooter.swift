import Abstractions
import Database
import SwiftUI
#if os(iOS)
    import UIKit
#endif

// MARK: - Message Input Footer

internal struct InputFooter: View {
    // MARK: - Constants

    private enum Constants {
        static let horizontalSpacing: CGFloat = 14
        static let attachmentPadding: CGFloat = 1
        static let minHeight: CGFloat = 44
    }

    // MARK: - State

    @Bindable var chat: Chat
    @Binding var selectedAction: Action

    let canStop: () -> Bool
    let canSend: () -> Bool
    let onSend: () -> Void

    // MARK: - Views

    var body: some View {
        HStack(alignment: .center, spacing: Constants.horizontalSpacing) {
            AttachmentButton(chat: chat)
                .padding(Constants.attachmentPadding)
            VoiceButton(chat: chat)

            // Show tools button only when no tool is selected
            if selectedAction.tools.isEmpty, selectedAction.isTextual {
                ToolSelectionButton(
                    chat: chat,
                    selectedAction: $selectedAction
                )
            }

            // Show selected tool chips if any
            if !selectedAction.tools.isEmpty {
                ToolChipsContainer(tools: selectedAction.tools) { tool in
                    removeTool(tool)
                }
            }

            Spacer()
            if canSend() {
                SendButton(onSend: onSend)
                    .transition(.opacity.combined(with: .scale))
                    .animation(.spring(), value: canSend())
            } else if canStop() {
                StopGenerationButton(chat: chat)
                    .transition(.opacity.combined(with: .scale))
                    .animation(.spring(), value: canStop())
            }
        }
        .frame(minHeight: Constants.minHeight)
    }

    // MARK: - Private Methods

    private func removeTool(_ tool: ToolIdentifier) {
        var currentTools: Set<ToolIdentifier> = selectedAction.tools
        currentTools.remove(tool)

        if currentTools.isEmpty {
            selectedAction = .textGeneration([])
        } else {
            switch selectedAction {
            case .textGeneration:
                selectedAction = .textGeneration(currentTools)

            case .imageGeneration:
                selectedAction = .imageGeneration(currentTools)
            }
        }
    }
}

// MARK: - Preview

#if DEBUG
    #Preview {
        @Previewable @State var chat: Chat = .preview
        @Previewable @State var selectedAction: Action = .textGeneration([])

        InputFooter(
            chat: chat,
            selectedAction: $selectedAction,
            canStop: { false },
            canSend: { false },
            onSend: {
                // no-op
            }
        )
    }
#endif
