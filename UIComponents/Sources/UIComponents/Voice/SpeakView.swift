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
    @State private var isTalkModeActive: Bool = false

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

                ControlButtonsView(
                    isRecording: $isRecording,
                    isTalkModeActive: $isTalkModeActive
                )
            }
            .padding(.horizontal, LayoutVoice.Spacing.medium)
        }
        .task {
            let talkModeEnabled = await audioViewModel.isTalkModeEnabled
            await MainActor.run {
                isTalkModeActive = talkModeEnabled
            }
            if talkModeEnabled {
                await audioViewModel.startTalkMode(generator: generator)
            } else {
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
                if isTalkModeActive {
                    await audioViewModel.stopTalkMode()
                } else {
                    await audioViewModel.stopListening()
                }
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
