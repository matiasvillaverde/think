import Abstractions
@testable import AgentOrchestrator
@testable import Database
import Foundation
import Testing

/// Helpers for verifying agentic loop acceptance test results
internal enum AgenticLoopVerificationHelpers {
    private enum ExpectedValues {
        static let expectedToolExecutions: Int = 1
        static let expectedChannelCount: Int = 3
        static let expectedStepsValue: Int = 8_543
    }

    // MARK: - Health Tool Verification

    internal static func verifyHealthToolExecution(_ healthTool: TestHealthStrategy) throws {
        let history: [TestHealthStrategy.HealthRecord] = healthTool.executionHistory
        let expected: Int = ExpectedValues.expectedToolExecutions
        #expect(history.count == expected, "Expected \(expected) health tool execution, got \(history.count)")

        guard !history.isEmpty else {
            Issue.record("No health tool executions recorded")
            return
        }

        let record: TestHealthStrategy.HealthRecord = history[0]
        #expect(record.metric == "steps")
        #expect(record.value == Double(ExpectedValues.expectedStepsValue))
        #expect(record.unit == "steps")
        #expect(record.date == "yesterday")
    }

    // MARK: - Message Structure Verification
    @MainActor
    internal static func verifyHealthMessageStructure(
        database: Database,
        chatId: UUID
    ) async throws {
        let messages: [Message] = try await database.read(
            MessageCommands.GetAll(chatId: chatId)
        )
        #expect(messages.count == 1, "Expected exactly 1 message")

        guard let message = messages.first else {
            Issue.record("No messages found")
            return
        }

        #expect(message.userInput == "How many steps did I walk yesterday?")
        #expect(message.response != nil, "Message should have a response")

        try verifyChannelStructure(message)
    }

    private static func verifyChannelStructure(_ message: Message) throws {
        guard let channels = message.channels else {
            Issue.record("Message should have channels")
            return
        }

        debugPrintChannels(channels)

        let expected: Int = ExpectedValues.expectedChannelCount
        #expect(channels.count == expected, "Expected \(expected) channels: commentary, tool, final")

        let commentaryChannels: [Channel] = channels.filter { $0.type == .commentary }
        let toolChannels: [Channel] = channels.filter { $0.type == .tool }
        let finalChannels: [Channel] = channels.filter { $0.type == .final }

        #expect(commentaryChannels.count == 1, "Expected 1 commentary channel")
        #expect(toolChannels.count == 1, "Expected 1 tool channel")
        #expect(finalChannels.count == 1, "Expected 1 final channel")

        try verifyToolChannel(toolChannels.first)
        try verifyCommentaryChannel(commentaryChannels.first)
        try verifyFinalChannel(finalChannels.first)
    }

    private static func debugPrintChannels(_ channels: [Channel]) {
        print("DEBUG: Found \(channels.count) channels:")
        for (index, channel) in channels.enumerated() {
            print("  Channel \(index): type=\(channel.type), content='\(channel.content.prefix(100))...'")
            if let toolExecution = channel.toolExecution {
                print("    - Has tool execution: \(toolExecution.request?.name ?? "unknown")")
            }
        }
    }

    // MARK: - Channel Verification
    private static func verifyToolChannel(_ channel: Channel?) throws {
        guard let channel else {
            Issue.record("Tool channel not found")
            return
        }

        guard let toolExecution = channel.toolExecution,
            let request = toolExecution.request else {
            Issue.record("Tool channel should have tool execution with request")
            return
        }

        #expect(request.name == "health_data")
        #expect(request.arguments.contains("steps"))
        #expect(request.arguments.contains("yesterday"))

        guard let response = toolExecution.response else {
            Issue.record("Tool execution should have response")
            return
        }

        #expect(response.result.contains(String(ExpectedValues.expectedStepsValue)))
        #expect(response.result.contains("steps"))
    }

    private static func verifyCommentaryChannel(_ channel: Channel?) throws {
        guard let channel else {
            Issue.record("Commentary channel not found")
            return
        }

        #expect(channel.content.contains("health data"))
        #expect(channel.content.contains("step"))
    }

    private static func verifyFinalChannel(_ channel: Channel?) throws {
        guard let channel else {
            Issue.record("Final channel not found")
            return
        }

        #expect(channel.content.contains("8,543"))
        #expect(channel.content.contains("steps"))
        #expect(channel.content.contains("yesterday"))
    }
}
