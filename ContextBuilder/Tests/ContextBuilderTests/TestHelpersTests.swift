import Abstractions
@testable import ContextBuilder
import Foundation
import Testing

/// Tests for TestHelpers channel creation utilities
@Suite("TestHelpers Tests")
internal struct TestHelpersTests {
    @Test("createCommentaryChannel creates correct channel type")
    func testCreateCommentaryChannel() throws {
        // Given
        let content = "This is commentary"
        let order = 1
        let toolId = UUID()

        // When
        let channel = TestHelpers.createCommentaryChannel(
            content: content,
            order: order,
            associatedToolId: toolId
        )

        // Then
        #expect(channel.type == .commentary)
        #expect(channel.content == content)
        #expect(channel.order == order)
        #expect(channel.associatedToolId == toolId)
    }

    @Test("createFinalChannel creates correct channel type")
    func testCreateFinalChannel() throws {
        // Given
        let content = "This is final content"
        let order = 2

        // When
        let channel = TestHelpers.createFinalChannel(
            content: content,
            order: order
        )

        // Then
        #expect(channel.type == .final)
        #expect(channel.content == content)
        #expect(channel.order == order)
        #expect(channel.associatedToolId == nil)
    }

    @Test("createMessageDataWithChannels creates correct MessageData")
    func testCreateMessageDataWithChannels() throws {
        // Given
        let userInput = "Test input"
        let channels = [
            TestHelpers.createCommentaryChannel(content: "Commentary"),
            TestHelpers.createFinalChannel(content: "Final")
        ]
        let toolCall = ToolCall(name: "test", arguments: "{}", id: UUID().uuidString)

        // When
        let messageData = TestHelpers.createMessageDataWithChannels(
            userInput: userInput,
            channels: channels,
            toolCalls: [toolCall]
        )

        // Then
        #expect(messageData.userInput == userInput)
        #expect(messageData.channels.count == 2)
        #expect(messageData.channels[0].type == .commentary)
        #expect(messageData.channels[1].type == .final)
        #expect(messageData.toolCalls.count == 1)
        #expect(messageData.toolCalls[0].name == "test")
    }

    @Test("createMessageDataWithChannels works with defaults")
    func testCreateMessageDataWithChannelsDefaults() throws {
        // When
        let messageData = TestHelpers.createMessageDataWithChannels()

        // Then
        #expect(messageData.userInput == nil)
        #expect(messageData.channels.isEmpty)
        #expect(messageData.toolCalls.isEmpty)
    }

    @Test("channel helpers work with formatting")
    func testChannelHelpersWithFormatting() throws {
        // Given
        let formatter = ChatMLContextFormatter(labels: ChatMLLabels())
        let messageData = TestHelpers.createMessageDataWithChannels(
            channels: [
                TestHelpers.createCommentaryChannel(content: "I'll help", order: 0),
                TestHelpers.createFinalChannel(content: "Here's the answer", order: 1)
            ]
        )

        // When
        let result = try formatter.formatAssistantMessageFromChannels(messageData)

        // Then
        #expect(result.contains("<commentary>"))
        #expect(result.contains("I'll help"))
        #expect(result.contains("</commentary>"))
        #expect(result.contains("Here's the answer"))
    }
}
