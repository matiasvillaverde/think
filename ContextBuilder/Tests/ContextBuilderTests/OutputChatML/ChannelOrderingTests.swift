import Abstractions
@testable import ContextBuilder
import Foundation
import Testing

/// Tests for complex channel and tool ordering logic
@Suite("Channel Ordering Tests")
internal struct ChannelOrderingTests {
    @Test("Commentary associated with tool should appear before the tool")
    func testToolAssociatedCommentary() {
        // Given
        let formatter = ChatMLContextFormatter(labels: ChatMLLabels())
        let toolId = UUID()
        let messageData = TestHelpers.createMessageDataWithChannels(
            channels: [
                TestHelpers.createCommentaryChannel(
                    content: "I'll find for that",
                    order: 0,
                    associatedToolId: toolId
                ),
                TestHelpers.createFinalChannel(
                    content: "Here are the results",
                    order: 2
                )
            ],
            toolCalls: [
                ToolCall(name: "search", arguments: "{\"query\":\"test\"}", id: toolId.uuidString)
            ]
        )

        // When
        let result = formatter.formatAssistantMessageFromChannels(messageData)

        // Then - Commentary should appear before its associated tool
        let commentaryRange = result.range(of: "I'll find for that")
        let toolRange = result.range(of: "search")
        #expect(commentaryRange != nil)
        #expect(toolRange != nil)
        if let cRange = commentaryRange, let tRange = toolRange {
            #expect(cRange.lowerBound < tRange.lowerBound)
        }
    }

    @Test("Multiple tools with associated commentary maintain proper order")
    func testMultipleToolsWithCommentary() {
        // Given
        let formatter = ChatMLContextFormatter(labels: ChatMLLabels())
        let searchToolId = UUID()
        let weatherToolId = UUID()

        let messageData = TestHelpers.createMessageDataWithChannels(
            channels: [
                TestHelpers.createCommentaryChannel(
                    content: "First, I'll search",
                    order: 0,
                    associatedToolId: searchToolId
                ),
                TestHelpers.createCommentaryChannel(
                    content: "Then check weather",
                    order: 1,
                    associatedToolId: weatherToolId
                ),
                TestHelpers.createFinalChannel(
                    content: "Results ready",
                    order: 3
                )
            ],
            toolCalls: [
                ToolCall(name: "search", arguments: "{}", id: searchToolId.uuidString),
                ToolCall(name: "weather", arguments: "{}", id: weatherToolId.uuidString)
            ]
        )

        // When
        let result = formatter.formatAssistantMessageFromChannels(messageData)

        // Then - Each commentary appears before its tool
        // "First"
        let searchCommentaryIndex = result.firstIndex(of: "F") ?? result.endIndex
        let searchToolIndex = result.range(of: "\"name\": \"search\"")?.lowerBound
            ?? result.endIndex
        // "Then"  
        let weatherCommentaryIndex = result.firstIndex(of: "T") ?? result.endIndex
        let weatherToolIndex = result.range(of: "\"name\": \"weather\"")?.lowerBound
            ?? result.endIndex

        #expect(searchCommentaryIndex < searchToolIndex)
        #expect(weatherCommentaryIndex < weatherToolIndex)
        // First tool complete before second commentary
        #expect(searchToolIndex < weatherCommentaryIndex)
    }

    @Test("Mixed associated and non-associated channels preserve order")
    func testMixedChannelAssociation() {
        // Given
        let formatter = ChatMLContextFormatter(labels: ChatMLLabels())
        let toolId = UUID()

        let messageData = TestHelpers.createMessageDataWithChannels(
            channels: [
                TestHelpers.createCommentaryChannel(
                    content: "General commentary",
                    order: 0
                ),
                TestHelpers.createCommentaryChannel(
                    content: "Tool-specific commentary",
                    order: 1,
                    associatedToolId: toolId
                ),
                TestHelpers.createFinalChannel(
                    content: "Final message",
                    order: 3
                )
            ],
            toolCalls: [
                ToolCall(name: "process", arguments: "{}", id: toolId.uuidString)
            ]
        )

        // When
        let result = formatter.formatAssistantMessageFromChannels(messageData)

        // Then
        let generalIndex = result.range(of: "General commentary")?.lowerBound
            ?? result.endIndex
        let toolCommentaryIndex = result.range(of: "Tool-specific commentary")?.lowerBound
            ?? result.endIndex
        let toolIndex = result.range(of: "\"name\": \"process\"")?.lowerBound
            ?? result.endIndex
        let finalIndex = result.range(of: "Final message")?.lowerBound
            ?? result.endIndex

        // Order should be: general -> tool-specific -> tool -> final
        #expect(generalIndex < toolCommentaryIndex)
        #expect(toolCommentaryIndex < toolIndex)
        #expect(toolIndex < finalIndex)
    }

    @Test("Tool calls without channels still format correctly")
    func testToolCallsWithoutChannels() {
        // Given
        let formatter = ChatMLContextFormatter(labels: ChatMLLabels())
        let messageData = TestHelpers.createMessageDataWithChannels(
            channels: [],
            toolCalls: [
                ToolCall(name: "standalone", arguments: "{\"test\":true}", id: UUID().uuidString)
            ]
        )

        // When
        let result = formatter.formatAssistantMessageFromChannels(messageData)

        // Then
        #expect(result.contains("<tool_call>"))
        #expect(result.contains("\"name\": \"standalone\""))
        #expect(result.contains("</tool_call>"))
    }

    @Test("Empty message returns empty string")
    func testEmptyMessage() {
        // Given
        let formatter = ChatMLContextFormatter(labels: ChatMLLabels())
        let messageData = TestHelpers.createMessageDataWithChannels()

        // When
        let result = formatter.formatAssistantMessageFromChannels(messageData)

        // Then
        #expect(result.isEmpty)
    }

    @Test("OrderedItem enum properly orders channels and tools")
    func testOrderedItemEnum() {
        // Given
        let channel = TestHelpers.createCommentaryChannel(content: "Test", order: 5)
        let toolCall = ToolCall(name: "test", arguments: "{}", id: UUID().uuidString)

        let channelItem = ChatMLContextFormatter.OrderedItem.channel(channel)
        let toolItem = ChatMLContextFormatter.OrderedItem.toolCall(toolCall)

        // When/Then
        #expect(channelItem.order == 5)
        #expect(toolItem.order == Int.max)  // Tools should have max order
    }
}
