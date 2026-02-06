import Abstractions
import Database
import SwiftData
import SwiftUI

// MARK: - ChatContentView

public struct ChatContentView: View {
    @Bindable private var chat: Chat
    private let messageCount: Int

    @Query private var files: [FileAttachment]

    @Environment(\.generator)
    private var generator: ViewModelGenerating

    enum Constants: Sendable {
        static let padding: CGFloat = 8
        static let hStackSpacing: CGFloat = 12
        static let horizontalPadding: CGFloat = 10
        static let minHeight: CGFloat = 44
        static let opacity: Double = 0.5
    }

    public init(
        chat: Chat,
        messageCount: Int
    ) {
        self.chat = chat
        self.messageCount = messageCount
        let id: UUID = chat.id
        _files = Query(
            filter: #Predicate<FileAttachment> { file in
                file.chat?.id == id && file.message == nil
            },
            sort: \FileAttachment.createdAt,
            order: .reverse,
            animation: .easeInOut
        )
    }

    public var body: some View {
        VStack(spacing: 0) {
            ZStack {
                MessagesContainerView(chat: chat)

                VStack {
                    Spacer()
                    fileAttachmentsView
                }
                .padding(.top)
            }

            if shouldShowPromptsOrSkeleton() {
                PromptsView(chat: chat)
            }

            MessageInputView(chat: chat)
                .background(.clear)
        }
        .task(id: chat.id) {
            // Load the model when the view appears
            await loadModel()
        }
        .onChange(of: chat.languageModel.state) { _, _ in
            // Load the model when state changes to downloaded
            Task {
                await loadModel()
            }
        }
    }

    private func loadModel() async {
        await generator.load(chatId: chat.id)
    }

    private func shouldShowPromptsOrSkeleton() -> Bool {
        // Show prompts when it's the first message and model is loaded
        // Show skeleton when it's the first message and model is loading
        if messageCount == 0 {
            return chat.languageModel.runtimeState == .loaded ||
                chat.languageModel.runtimeState == .loading
        }

        // Also show skeleton if there are messages and the last message's models are loading
        if let lastMessage = chat.messages.last {
            return lastMessage.languageModel.runtimeState == .loading ||
                lastMessage.imageModel.runtimeState == .loading
        }

        return false
    }

    private var fileAttachmentsView: some View {
        Group {
            if !files.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: Constants.hStackSpacing) {
                        ForEach(files) { file in
                            FileAttachmentView(file: file)
                        }
                    }
                    .padding(Constants.horizontalPadding)
                    .frame(minHeight: Constants.minHeight)
                }
            }
        }
    }
}
