@testable import UIComponents
import SwiftUI
import Database
#if os(iOS)
import UIKit
#endif

// MARK: - App
@main
struct App_ScreenshotsApp: App {
    @State var chat: Chat = .preview
    @State var isShowing: Bool = true
    @State private var viewToShow: String

    init() {
        // Check launch arguments to determine which view to show
        if CommandLine.arguments.contains("-SHOW_STATISTICS") {
            self._viewToShow = State(initialValue: "statistics")
        } else if CommandLine.arguments.contains("-SHOW_MODEL_SELECTION") {
            self._viewToShow = State(initialValue: "modelSelection")
        } else if CommandLine.arguments.contains("-SHOW_PERSONALITIES") {
            self._viewToShow = State(initialValue: "personalities")
        } else if CommandLine.arguments.contains("-SHOW_CHAT_MESSAGES") {
            self._viewToShow = State(initialValue: "chatMessages")
        } else if CommandLine.arguments.contains("-SHOW_CHAT_CODE") {
            self._viewToShow = State(initialValue: "chatCode")
        } else if CommandLine.arguments.contains("-SHOW_CHAT_IMAGES") {
            self._viewToShow = State(initialValue: "chatImages")
        } else if CommandLine.arguments.contains("-SHOW_CHAT_THINKING") {
            self._viewToShow = State(initialValue: "chatThinking")
        } else if CommandLine.arguments.contains("-SHOW_CHAT_FILES") {
            self._viewToShow = State(initialValue: "chatFiles")
        } else if CommandLine.arguments.contains("-SHOW_VOICE") {
            self._viewToShow = State(initialValue: "voice")
        } else {
            // Default view if no specific argument is provided
            self._viewToShow = State(initialValue: "statistics")
        }

        // Disable animations
        #if os(iOS)
        UIView.setAnimationsEnabled(false)
        #endif
    }

    var body: some Scene {
        WindowGroup {
            switch viewToShow {
            case "statistics":
                ChatMetricsDashboard(
                    metrics: marketingMetrics,
                    chatId: "readme",
                    chatTitle: "Performance"
                )
                .background(Color.backgroundPrimary)
            case "modelSelection":
                ModelSelectionView(chat: chat)
                    .modifier(AppPreviewDatabase())
            case "personalities":
                PersonalitiesMarketingView()
            case "chatMessages":
                ChatContainerView(
                    messages: {
                        #if os(iOS)
                        if UIDevice.current.userInterfaceIdiom == .phone {
                            [Message.regularMessages]
                        } else {
                            [Message.regularMessages, Message.followUpMessage, Message.kidLovedItMessage]
                        }
                        #else
                        [Message.regularMessages, Message.followUpMessage, Message.kidLovedItMessage]
                        #endif
                    }(),
                    chat: .preview,
                    overrideShouldDraw: false
                )
            case "chatCode":
                ChatContainerView(
                    messages: {
#if os(iOS)
                        if UIDevice.current.userInterfaceIdiom == .phone {
                            [Message.codeMessages]
                        } else {
                            [Message.previewComplexConversation]
                        }
#else
                        [Message.previewComplexConversation]
#endif
                    }(),
                    chat: chat,
                    overrideShouldDraw: false
                )
            case "chatImages":
                ChatContainerView(
                    messages: [Message.imageMessages],
                    chat: chat,
                    overrideShouldDraw: true
                )
            case "chatThinking":
                ChatContainerView(
                    messages: [Message.thinkingMessages],
                    chat: chat,
                    overrideShouldDraw: false
                )
            case "chatFiles":
                ChatContainerView(
                    messages: [
                        Message.previewWithFile,
                        Message.followUpMessageFile
                    ],
                    chat: chat,
                    overrideShouldDraw: false
                )
            case "voice":
                SpeakView(chat: chat)
            default:
                ModelSelectionView(chat: chat)
                    .modifier(AppPreviewDatabase())
            }
        }
    }

    private var marketingMetrics: [Metrics] {
        // Deterministic fake data for dashboards / marketing screenshots.
        var items: [Metrics] = []
        items.reserveCapacity(24)
        for idx in 0..<24 {
            items.append(
                Metrics.preview(
                    totalTime: 0.9 + (Double(idx % 6) * 0.15),
                    timeToFirstToken: 0.08 + (Double(idx % 4) * 0.02),
                    promptTokens: 420 + (idx * 3),
                    generatedTokens: 380 + (idx * 5),
                    totalTokens: 800 + (idx * 8),
                    contextWindowSize: 8192,
                    contextTokensUsed: 900 + (idx * 10),
                    contextUtilization: 0.18 + (Double(idx) * 0.01),
                    modelName: "On-device",
                    createdAt: Date().addingTimeInterval(TimeInterval(-idx * 60))
                )
            )
        }
        return items
    }
}

// MARK: - ChatContainerView
struct ChatContainerView: View {

    let messages: [Message]
    let chat: Chat
    let overrideShouldDraw: Bool

    @FocusState private var inputIsFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            ChatMessagesView(messages: messages)
            MessageInputView(
                chat: chat,
                overrideCanSend: true,
                overrideShouldDraw: overrideShouldDraw
            )
                .background(.clear)
                .focused($inputIsFocused)
                .onAppear {
                    inputIsFocused = false

                    // Add timer to ensure focus is disabled after a delay
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                        inputIsFocused = false
                    }
                }

        }
        .background(Color.backgroundPrimary)
        .ignoresSafeArea(edges: .bottom)
    }

    private func localized() {
        // It should be translated to all these languages:
        // ar-SA,ca,cs,da,de-DE,el,en-AU,en-CA,en,en-GB,en-US,es-ES,es-MX,fi,fr-CA,fr-FR,he,hi,hr,hu,id,it,ja,ko,ms,nl-NL,no,pl,pt-BR,pt-PT,ro,ru,sk,sv,th,tr,uk,vi,zh-Hans,zh-Hant

        _ = String(
            localized: "TITLE_1", defaultValue: "Think AI",
            comment: "Marketing tagline with the app's name"
        )
        _ = String(
            localized: "TITLE_2", defaultValue: "All without compromising your privacy",
            comment: "Title of the app to showcase how it protects user privacy"
        )
        _ = String(
            localized: "TITLE_3", defaultValue: """
        Get answers.
        Find inspiration.
        Be more productive.
        """,
            comment: "Title of the app to showcase three main features"
        )
        _ = String(
            localized: "TITLE_4", defaultValue: "Chat with your files privately",
            comment: "Screenshot title to showcase how the AI app can use RAG to chat with your files in private"
        )
        _ = String(
            localized: "TITLE_5", defaultValue: "Generate images offline",
            comment: "Title of the app to showcase how it generates images offline"
        )
        _ = String(
            localized: "TITLE_6", defaultValue: "Privacy-first AI. Protect yourself",
            comment: "Title of the app to showcase how it protects user privacy"
        )
        _ = String(
            localized: "TITLE_7", defaultValue: "Deep thinking for thought questions",
            comment: "Feature highlight for AI's advanced reasoning capabilities"
        )
        _ = String(
            localized: "TITLE_8", defaultValue: "Work smarter with Think",
            comment: "Screenshot title to showcase how the AI app can help the user with coding"
        )
        _ = String(
            localized: "TITLE_9", defaultValue: "Open source models",
            comment: "Title of the app to showcase how it uses open source models"
        )
        _ = String(
            localized: "TITLE_10", defaultValue: "Statistics about your models",
            comment: "Feature description for section showing AI model performance metrics"
        )
        _ = String(
            localized: "TITLE_11", defaultValue: "Dark Mode",
            comment: "Feature highlight for dark mode option"
        )
        _ = String(
            localized: "TITLE_12", defaultValue: "Download Open Source Models",
            comment: "Title of the app to showcase how it downloads open source models"
        )
        _ = String(
            localized: "TITLE_13", defaultValue: "Privacy-first AI to Protect yourself",
            comment: "Title of the app to showcase how it protects user privacy"
        )
    }
}

// MARK: - ChatMessagesView
struct ChatMessagesView: View {
    let messages: [Message]

    var body: some View {
        ScrollView {
            LazyVStack {
                ForEach(messages) { message in
                    MessageView(message: message)
                }
            }
        }
        .padding(.leading, 2)
        .padding(.trailing, 2)
    }
}

// MARK: - Marketing Screens
private struct PersonalitiesMarketingView: View {
    private struct MarketingPersonality: Identifiable {
        let id: String
        let name: String
        let description: String
        let imageName: String
        let tint: Color
    }

    private let personalities: [MarketingPersonality] = [
        .init(
            id: "buddy",
            name: "Buddy",
            description: "Upbeat, loyal, and real with you",
            imageName: "friend-icon",
            tint: .blue
        ),
        .init(
            id: "girlfriend",
            name: "Girlfriend",
            description: "Warm relationship advice, no judgment",
            imageName: "girlfriend-icon",
            tint: .pink
        ),
        .init(
            id: "coach",
            name: "Life Coach",
            description: "Clear plans, consistent follow-through",
            imageName: "coach-icon",
            tint: .orange
        ),
        .init(
            id: "work",
            name: "Work Coach",
            description: "Pragmatic help for real work",
            imageName: "work-coach-icon",
            tint: .green
        ),
        .init(
            id: "teacher",
            name: "Teacher",
            description: "Explains concepts at your level",
            imageName: "teacher-icon",
            tint: .purple
        )
    ]

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(personalities) { item in
                        HStack(spacing: 12) {
                            ZStack {
                                Circle()
                                    .fill(item.tint.opacity(0.2))
                                    .frame(width: 54, height: 54)

                                Image(item.imageName, bundle: .module)
                                    .resizable()
                                    .interpolation(.high)
                                    .scaledToFill()
                                    .frame(width: 54, height: 54)
                                    .clipShape(Circle())
                                    .accessibilityLabel(item.name)
                            }

                            VStack(alignment: .leading, spacing: 2) {
                                Text(item.name)
                                    .font(.headline)
                                    .lineLimit(1)

                                Text(item.description)
                                    .font(.caption)
                                    .foregroundStyle(Color.textSecondary)
                                    .lineLimit(1)
                            }

                            Spacer()
                        }
                        .padding(.vertical, 4)
                    }
                } header: {
                    Text("Your personal team")
                } footer: {
                    Text("Each personality is its own OpenClaw instance.")
                }
            }
            .listStyle(.sidebar)
            .navigationTitle("Personalities")
            .navigationBarTitleDisplayMode(.inline)
            .background(Color.backgroundPrimary)
        }
    }
}

// MARK: - Preview Providers
#Preview("Statistics Chart") {
    ChatMetricsDashboard(metrics: [Metrics.preview(), Metrics.preview(), Metrics.preview()])
        .background(Color.backgroundPrimary)
}

#Preview("Model Selection") {
    ModelSelectionView(chat: .preview)
        .modifier(AppPreviewDatabase())
}

#Preview("Voice") {
    SpeakView(chat: .preview)
}

#Preview("Chat - Regular Messages") {
    ChatContainerView(
        messages: {
            #if os(iOS)
            if UIDevice.current.userInterfaceIdiom == .phone {
                [Message.regularMessages]
            } else {
                [Message.regularMessages, Message.followUpMessage, Message.kidLovedItMessage]
            }
            #else
            [Message.regularMessages, Message.followUpMessage, Message.kidLovedItMessage]
            #endif
        }(),
        chat: .preview,
        overrideShouldDraw: false
    )
}

#Preview("Chat - Code Messages") {
    ChatContainerView(
        messages: {
#if os(iOS)
            if UIDevice.current.userInterfaceIdiom == .phone {
                [Message.codeMessages]
            } else {
                [Message.previewComplexConversation]
            }
#else
            [Message.previewComplexConversation]
#endif
        }(),
        chat: .preview,
        overrideShouldDraw: false
    )
}

#Preview("Chat - Image Messages") {
    ChatContainerView(
        messages: [Message.imageMessages],
        chat: .preview,
        overrideShouldDraw: true
    )
}

#Preview("Chat - Thinking Messages") {
    ChatContainerView(
        messages: [Message.thinkingMessages],
        chat: .preview,
        overrideShouldDraw: false
    )
}

#Preview("Chat - With Files") {
    ChatContainerView(
        messages: [Message.previewWithFile, Message.followUpMessageFile],
        chat: .preview,
        overrideShouldDraw: false
    )
}
