import Abstractions
@testable import ContextBuilder
import Foundation
import Testing

/// Tests for channel-based message formatting functionality
@Suite("Message Formatting Tests")
internal struct MessageFormattingTests {
    @Test("ChatML formatter should format channels correctly")
    func testChatMLChannelFormatting() throws {
        // Given
        let formatter = ChatMLContextFormatter(labels: ChatMLLabels())
        let channels = [
            MessageChannel(type: .commentary, content: "I'll help you with that", order: 0),
            MessageChannel(type: .final, content: "Here's the answer", order: 1)
        ]
        let messageData = MessageData(
            id: UUID(),
            createdAt: Date(),
            userInput: nil,
            channels: channels,
            toolCalls: []
        )

        // When - This should fail initially since the method doesn't exist
        let result = try formatter.formatAssistantMessageFromChannels(messageData)

        // Then
        #expect(result.contains("<commentary>"))
        #expect(result.contains("I'll help you with that"))
        #expect(result.contains("</commentary>"))
        #expect(result.contains("Here's the answer"))
    }

    @Test("Formatter should handle empty channels array")
    func testEmptyChannelsFormatting() throws {
        // Given
        let formatter = ChatMLContextFormatter(labels: ChatMLLabels())
        let messageData = MessageData(
            id: UUID(),
            createdAt: Date(),
            userInput: nil,
            channels: [],
            toolCalls: []
        )

        // When
        let result = try formatter.formatAssistantMessageFromChannels(messageData)

        // Then
        #expect(result.isEmpty)
    }

    @Test("Formatter should respect channel ordering")
    func testChannelOrdering() throws {
        // Given
        let formatter = ChatMLContextFormatter(labels: ChatMLLabels())
        let channels = [
            MessageChannel(type: .final, content: "Second content", order: 1),
            MessageChannel(type: .commentary, content: "First content", order: 0)
        ]
        let messageData = MessageData(
            id: UUID(),
            createdAt: Date(),
            userInput: nil,
            channels: channels,
            toolCalls: []
        )

        // When
        let result = try formatter.formatAssistantMessageFromChannels(messageData)

        // Then - Commentary (order 0) should appear before final (order 1)
        let commentaryIndex = result.firstIndex(of: "F") ?? result.endIndex // "First content"
        let finalIndex = result.firstIndex(of: "S") ?? result.endIndex // "Second content"
        #expect(commentaryIndex < finalIndex)
    }
}
