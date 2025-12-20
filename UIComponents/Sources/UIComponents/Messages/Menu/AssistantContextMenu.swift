import Abstractions
import Database
import SwiftUI

// **MARK: - Assistant Context Menu**
public struct AssistantContextMenu: View {
    let textToCopy: String
    @Bindable var message: Message
    @Binding var showingSelectionView: Bool
    @Binding var showingThinkingView: Bool
    @Binding var showingStatsView: Bool
    let copyTextAction: (String) -> Void
    let shareTextAction: (String) -> Void

    @Environment(\.audioViewModel)
    var audioViewModel: AudioViewModeling

    public var body: some View {
        Group {
            Button(
                action: { shareTextAction(textToCopy)
                },
                label: {
                    Label(
                        String(
                            localized: "Share",
                            bundle: .module,
                            comment: "Action button label for sharing text"
                        ),
                        systemImage: "square.and.arrow.up"
                    )
                }
            )

            copyButton
            selectionButtonIfApplicable
            thinkingButtonIfAvailable
            statisticsButtonIfAvailable
            voiceButtonIfAvailable
        }
    }

    private var copyButton: some View {
        Button(
            action: { copyTextAction(textToCopy)
            },
            label: {
                Label(
                    String(
                        localized: "Copy",
                        bundle: .module,
                        comment: "Action button label for copying text"
                    ),
                    systemImage: "doc.on.doc"
                )
            }
        )
    }

    private var selectionButtonIfApplicable: some View {
        Group {
            #if os(iOS) || os(visionOS)
                Button(
                    action: {
                        showingSelectionView = true
                    },
                    label: {
                        Label(
                            String(
                                localized: "Select",
                                bundle: .module,
                                comment: "Action button label for selecting text"
                            ),
                            systemImage: "text.cursor"
                        )
                    }
                )
            #endif
        }
    }

    private var thinkingButtonIfAvailable: some View {
        Group {
            if message.thinking != nil {
                Button(
                    action: {
                        showingThinkingView.toggle()
                    },
                    label: {
                        Label(
                            String(
                                localized: "Thinking process",
                                bundle: .module,
                                comment: "Button label to view the thinking process"
                            ),
                            systemImage: "brain.filled.head.profile"
                        )
                    }
                )
            }
        }
    }

    private var statisticsButtonIfAvailable: some View {
        Group {
            if message.metrics != nil {
                Button(
                    action: { showingStatsView = true
                    },
                    label: {
                        Label(
                            String(
                                localized: "Statistics",
                                bundle: .module,
                                comment: "Button label to view the statistics"
                            ),
                            systemImage: "chart.bar.fill"
                        )
                    }
                )
            }
        }
    }

    private var voiceButtonIfAvailable: some View {
        Group {
            if let response = message.response {
                Button(
                    action: {
                        Task(priority: .userInitiated) {
                            await audioViewModel.say(response)
                        }
                    },
                    label: {
                        Label(
                            String(
                                localized: "Read aloud",
                                bundle: .module,
                                comment: "Button label to speak"
                            ),
                            systemImage: "waveform"
                        )
                    }
                )
            }
        }
    }
}
