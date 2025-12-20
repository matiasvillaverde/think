import Database
import SwiftUI

// MARK: - Voice Button

internal struct VoiceButton: View {
    @State private var isShowingSpeakView: Bool = false

    @Bindable var chat: Chat

    private enum Constants {
        static let animationDuration: TimeInterval = 0.25
        static let dampingFraction: CGFloat = 0.7
    }

    var body: some View {
        Button(action: tapped) {
            Image(systemName: "waveform")
                .frame(width: ButtonConstants.iconSize, height: ButtonConstants.iconSize)
                .menuStyle(.borderlessButton)
                .foregroundColor(Color.iconPrimary)
                .opacity(ButtonConstants.opacity)
                .accessibilityLabel(
                    String(
                        localized: "Interact with the AI using voice",
                        bundle: .module
                    )
                )
        }
        .buttonStyle(.borderless)
        .font(.title3)
        .help(
            String(
                localized: "Speak to the AI assistant",
                bundle: .module,
                comment: "Button label for speaking to the AI assistant"
            )
        )
        #if os(iOS)
        .fullScreenCover(isPresented: $isShowingSpeakView) {
            SpeakView(chat: chat)
        }
        #else
        .sheet(isPresented: $isShowingSpeakView, onDismiss: nil) {
            SpeakView(chat: chat)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .edgesIgnoringSafeArea(.all)
        }
        #endif
    }

    private func tapped() {
        withAnimation(
            .spring(
                response: Constants.animationDuration,
                dampingFraction: Constants.dampingFraction
            )
        ) {
            isShowingSpeakView = true
        }
    }
}

// MARK: - Preview

#if DEBUG
    #Preview {
        @Previewable @State var chat: Chat = .preview
        VoiceButton(chat: chat)
    }
#endif
