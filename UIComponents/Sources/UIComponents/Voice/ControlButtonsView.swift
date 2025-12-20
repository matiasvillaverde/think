import Abstractions
import SwiftUI

/// Bottom control buttons for microphone and close
internal struct ControlButtonsView: View {
    @Environment(\.dismiss)
    private var dismiss: DismissAction

    @Environment(\.audioViewModel)
    private var audioViewModel: AudioViewModeling

    @Environment(\.generator)
    private var generator: ViewModelGenerating

    @Binding var isRecording: Bool

    var body: some View {
        HStack {
            // Close button
            CircleButton(
                icon: "xmark",
                accessibilityLabel: "Close"
            ) {
                dismiss()
            }

            Spacer()

            // Microphone button
            if !isRecording {
                Text("Tap to speak", bundle: .module)
                    .foregroundStyle(Color.textSecondary)
                    .font(.caption)
                    .padding()

                CircleButton(
                    icon: "mic.fill",
                    accessibilityLabel: "Start Recording"
                ) {
                    onMicrophoneTap()
                }
            }
        }
        .padding(.horizontal, LayoutVoice.Spacing.small)
    }

    private func onMicrophoneTap() {
        Task {
            await audioViewModel.listen(generator: generator)
            isRecording = true
        }
    }
}

#Preview {
    @Previewable @State var isRecording: Bool = false
    ControlButtonsView(isRecording: $isRecording)
}
