import Abstractions
import Database
import Foundation

internal enum UITestSeedMessages {
    internal static func seedFirstMessage(database: DatabaseProtocol, chatId: UUID) async throws {
        let ids = UITestIDs.shared

        let messageId: UUID = try await database.write(
            MessageCommands.Create(chatId: chatId, userInput: "Hello", isDeepThinker: false)
        )

        let toolRequest = makeToolRequest(toolId: ids.toolExecutionId)
        let longRunningToolRequest = makeToolRequest(toolId: ids.toolExecutionId2)

        try await writeStreamingOutput(
            database: database,
            messageId: messageId,
            toolRequest: toolRequest,
            longRunningToolRequest: longRunningToolRequest
        )
        try await completeToolExecution(database: database, toolRequest: toolRequest)
        try await startLongRunningToolExecution(database: database)
        try await writeCompleteOutput(
            database: database,
            messageId: messageId,
            toolRequest: toolRequest,
            longRunningToolRequest: longRunningToolRequest
        )
    }

    internal static func seedSecondMessage(database: DatabaseProtocol, chatId: UUID) async throws {
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
        toolRequest: ToolRequest,
        longRunningToolRequest: ToolRequest
    ) async throws {
        let ids = UITestIDs.shared
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

    private static func completeToolExecution(database: DatabaseProtocol, toolRequest: ToolRequest) async throws {
        let ids = UITestIDs.shared
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

    private static func startLongRunningToolExecution(database: DatabaseProtocol) async throws {
        let ids = UITestIDs.shared
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
        toolRequest: ToolRequest,
        longRunningToolRequest: ToolRequest
    ) async throws {
        let ids = UITestIDs.shared
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
}
