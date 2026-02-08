import Abstractions
import Database
import SwiftData
import SwiftUI
import UIComponents

/// Deterministic, fast UI-test entry point.
///
/// Launch with `--ui-testing` to bypass onboarding and seed a single chat with:
/// - a streaming assistant response (final channel partial -> complete)
/// - a thinking channel
/// - a tool execution (request + result)
struct UITestRootView: View {
    @Environment(\.database) private var database: DatabaseProtocol

    @State private var didSeed: Bool = false
    @State private var seedError: String?

    var body: some View {
        Group {
            if let seedError {
                VStack(spacing: 12) {
                    Text("UI Test Seed Failed")
                        .font(.headline)
                    Text(seedError)
                        .font(.caption)
                        .textSelection(.enabled)
                }
                .padding()
            } else {
                UITestChatHostView()
            }
        }
        .task {
            guard !didSeed else { return }
            didSeed = true
            await seedIfNeeded()
        }
    }

    private func seedIfNeeded() async {
        do {
            try await UITestSeed.run(database: database)
        } catch {
            await MainActor.run {
                seedError = String(describing: error)
            }
        }
    }
}

private enum UITestSeed {
    static func run(database: DatabaseProtocol) async throws {
        _ = try await database.execute(AppCommands.Initialize())

        let personalityId: UUID = try await database.write(PersonalityCommands.WriteDefault())
        try await ensureUITestLanguageModel(database: database)

        let chatId: UUID = try await database.write(ChatCommands.Create(personality: personalityId))
        let firstMessageId: UUID = try await database.write(
            MessageCommands.Create(chatId: chatId, userInput: "Hello", isDeepThinker: false)
        )

        let ids = UITestIDs.shared
        let toolRequest = makeToolRequest(toolId: ids.toolExecutionId)
        let longRunningToolRequest = makeToolRequest(toolId: ids.toolExecutionId2)

        try await writeStreamingOutput(
            database: database,
            messageId: firstMessageId,
            ids: ids,
            toolRequest: toolRequest,
            longRunningToolRequest: longRunningToolRequest
        )
        try await completeToolExecution(database: database, ids: ids, toolRequest: toolRequest)
        try await startLongRunningToolExecution(database: database, ids: ids)
        try await writeCompleteOutput(
            database: database,
            messageId: firstMessageId,
            ids: ids,
            toolRequest: toolRequest,
            longRunningToolRequest: longRunningToolRequest
        )

        try await seedSecondMessage(database: database, chatId: chatId)
    }

    private static func ensureUITestLanguageModel(database: DatabaseProtocol) async throws {
        let languageModelName: String = "UITest Language Model (v2)"
        let languageDTO = ModelDTO(
            type: .language,
            backend: .mlx,
            name: languageModelName,
            displayName: languageModelName,
            displayDescription: "Deterministic UI test model",
            tags: ["ui-test"],
            skills: [],
            parameters: 1,
            ramNeeded: 0,
            size: 0,
            locationHuggingface: "mlx-community/uitest-language-model",
            locationKind: .huggingFace,
            version: 2,
            architecture: .unknown
        )

        _ = try await database.write(ModelCommands.AddModels(modelDTOs: [languageDTO]))
        let languageModel: Model = try await database.read(ModelCommands.GetModel(name: languageModelName))
        _ = try await database.write(
            ModelCommands.UpdateModelDownloadProgress(id: languageModel.id, progress: 1.0)
        )
    }

    private static func makeToolRequest(toolId: UUID) -> ToolRequest {
        ToolRequest(
            name: "web_search",
            arguments: #"{ "query": "SwiftUI ScrollViewReader", "limit": 3 }"#,
            isComplete: true,
            displayName: "Web Search",
            recipient: "functions.web_search",
            id: toolId
        )
    }

    private static func writeStreamingOutput(
        database: DatabaseProtocol,
        messageId: UUID,
        ids: UITestIDs,
        toolRequest: ToolRequest,
        longRunningToolRequest: ToolRequest
    ) async throws {
        let partial = ProcessedOutput(
            channels: [
                ChannelMessage(
                    id: ids.analysisChannelId,
                    type: .analysis,
                    content: "Thinking about the best answer...",
                    order: 0,
                    isComplete: false
                ),
                ChannelMessage(
                    id: ids.commentaryChannelId,
                    type: .commentary,
                    content: "Searching docs...",
                    order: 1,
                    isComplete: false
                ),
                ChannelMessage(
                    id: ids.toolChannelId,
                    type: .tool,
                    content: "Tool: Web Search",
                    order: 2,
                    isComplete: true,
                    recipient: "functions.web_search",
                    toolRequest: toolRequest
                ),
                ChannelMessage(
                    id: ids.toolChannelId2,
                    type: .tool,
                    content: "Tool: Web Search",
                    order: 3,
                    isComplete: true,
                    recipient: "functions.web_search",
                    toolRequest: longRunningToolRequest
                ),
                ChannelMessage(
                    id: ids.finalChannelId,
                    type: .final,
                    content: "Here is a stre",
                    order: 4,
                    isComplete: false
                )
            ]
        )

        _ = try await database.write(
            MessageCommands.UpdateProcessedOutput(messageId: messageId, processedOutput: partial)
        )
    }

    private static func completeToolExecution(
        database: DatabaseProtocol,
        ids: UITestIDs,
        toolRequest: ToolRequest
    ) async throws {
        _ = try await database.write(ToolExecutionCommands.StartExecution(executionId: ids.toolExecutionId))
        _ = try await database.write(
            ToolExecutionCommands.UpdateProgress(
                executionId: ids.toolExecutionId,
                progress: 0.35,
                status: "Fetching results"
            )
        )

        try await Task.sleep(for: .milliseconds(250))

        let response = ToolResponse(
            requestId: ids.toolExecutionId,
            toolName: toolRequest.name,
            result: """
            {
              "results": [
                { "title": "SwiftUI", "url": "https://developer.apple.com/documentation/swiftui" }
              ]
            }
            """
        )

        _ = try await database.write(
            ToolExecutionCommands.Complete(executionId: ids.toolExecutionId, response: response)
        )
    }

    private static func startLongRunningToolExecution(database: DatabaseProtocol, ids: UITestIDs) async throws {
        _ = try await database.write(ToolExecutionCommands.StartExecution(executionId: ids.toolExecutionId2))
        _ = try await database.write(
            ToolExecutionCommands.UpdateProgress(
                executionId: ids.toolExecutionId2,
                progress: 0.15,
                status: "Fetching results"
            )
        )
    }

    private static func writeCompleteOutput(
        database: DatabaseProtocol,
        messageId: UUID,
        ids: UITestIDs,
        toolRequest: ToolRequest,
        longRunningToolRequest: ToolRequest
    ) async throws {
        let complete = ProcessedOutput(
            channels: [
                ChannelMessage(
                    id: ids.analysisChannelId,
                    type: .analysis,
                    content: "Thinking about the best answer... done.",
                    order: 0,
                    isComplete: true
                ),
                ChannelMessage(
                    id: ids.commentaryChannelId,
                    type: .commentary,
                    content: "Searching docs... done.",
                    order: 1,
                    isComplete: true
                ),
                ChannelMessage(
                    id: ids.toolChannelId,
                    type: .tool,
                    content: "Tool: Web Search",
                    order: 2,
                    isComplete: true,
                    recipient: "functions.web_search",
                    toolRequest: toolRequest
                ),
                ChannelMessage(
                    id: ids.toolChannelId2,
                    type: .tool,
                    content: "Tool: Web Search",
                    order: 3,
                    isComplete: true,
                    recipient: "functions.web_search",
                    toolRequest: longRunningToolRequest
                ),
                ChannelMessage(
                    id: ids.finalChannelId,
                    type: .final,
                    content: "Here is a streamed response that becomes complete.",
                    order: 4,
                    isComplete: true
                )
            ]
        )

        _ = try await database.write(
            MessageCommands.UpdateProcessedOutput(messageId: messageId, processedOutput: complete)
        )
    }

    private static func seedSecondMessage(database: DatabaseProtocol, chatId: UUID) async throws {
        let messageId: UUID = try await database.write(
            MessageCommands.Create(chatId: chatId, userInput: "Second message", isDeepThinker: false)
        )

        let output = ProcessedOutput(
            channels: [
                ChannelMessage(
                    id: UITestConstants.secondMessageFinalChannelId,
                    type: .final,
                    content: "Second response (complete).",
                    order: 0,
                    isComplete: true
                )
            ]
        )

        _ = try await database.write(
            MessageCommands.UpdateProcessedOutput(messageId: messageId, processedOutput: output)
        )
    }
}

private enum UITestConstants {
    static let secondMessageFinalChannelId = UUID(uuidString: "66666666-6666-6666-6666-666666666666")!
}

/// Host that always shows the first available chat.
private struct UITestChatHostView: View {
    @Query(sort: \Chat.createdAt) private var chats: [Chat]

    var body: some View {
        if let chat = chats.first {
            ChatView(chat: chat)
                .accessibilityIdentifier("uiTest.chatView")
        } else {
            ProgressView()
                .accessibilityIdentifier("uiTest.loading")
        }
    }
}

/// Hard-coded IDs so XCUITests can reliably query tool/channel views.
private struct UITestIDs: Sendable {
    static let shared = UITestIDs()

    let analysisChannelId = UUID(uuidString: "11111111-1111-1111-1111-111111111111")!
    let commentaryChannelId = UUID(uuidString: "22222222-2222-2222-2222-222222222222")!
    let toolChannelId = UUID(uuidString: "33333333-3333-3333-3333-333333333333")!
    let toolChannelId2 = UUID(uuidString: "77777777-7777-7777-7777-777777777777")!
    let finalChannelId = UUID(uuidString: "44444444-4444-4444-4444-444444444444")!
    let toolExecutionId = UUID(uuidString: "55555555-5555-5555-5555-555555555555")!
    let toolExecutionId2 = UUID(uuidString: "88888888-8888-8888-8888-888888888888")!
}
