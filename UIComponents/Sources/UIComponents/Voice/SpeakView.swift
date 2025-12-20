import Abstractions
import SwiftData
import SwiftUI

import class Database.Chat
import class Database.Metrics

/// Main screen containing the vapor circle and controls
public struct SpeakView: View {
    @Environment(\.audioViewModel)
    private var audioViewModel: AudioViewModeling

    @Environment(\.generator)
    private var generator: ViewModelGenerating

    @Bindable var chat: Chat

    // MARK: - Data

    @Query private var metrics: [Metrics]

    @State private var isRecording: Bool = true

    // MARK: - Initialization

    init(chat: Chat) {
        self.chat = chat
        _metrics = Query(
            sort: \Metrics.createdAt
        )
    }

    public var body: some View {
        ZStack {
            // Background color
            Color.backgroundPrimary.ignoresSafeArea()

            VStack {
                BetaBadge()

                Spacer()

                // Centered vapor circle
                FluidCircleView(
                    animationSpeed: AnimationConstants.FluidEffect.animationSpeed,
                    colorIntensity: AnimationConstants.FluidEffect.colorIntensity
                )
                .frame(
                    width: LayoutVoice.Size.circleView,
                    height: LayoutVoice.Size.circleView
                )
                .accessibilityLabel("Animated fluid visualization")
                BetaBadge()

                Spacer()

                ControlButtonsView(isRecording: $isRecording)
            }
            .padding(.horizontal, LayoutVoice.Spacing.medium)
        }.task {
            Task {
                await audioViewModel.listen(generator: generator)
            }
        }
        .onChange(of: metrics) {
            if let message = metrics.last?.message?.response {
                isRecording = false
                Task {
                    await audioViewModel.say(message)
                }
            }
        }
        .onDisappear {
            Task {
                await audioViewModel.stopListening()
            }
        }
    }
}

// MARK: - Preview

#if DEBUG
    #Preview {
        @Previewable @State var chat: Chat = .preview
        SpeakView(chat: chat)
    }
#endif
