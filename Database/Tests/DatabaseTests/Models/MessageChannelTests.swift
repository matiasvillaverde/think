import Testing
import Foundation
import SwiftData
@testable import Database
import Abstractions
import AbstractionsTestUtilities

@MainActor
@Suite("Message Channel Tests")
struct MessageChannelTests {
    @Test("Message can store channel data")
    func testMessageWithChannels() {
        // When - Create message with channels using preview models
        let message = Message.customPreview(
            userInput: "Test question",
            response: "Here is the answer",
            thinking: "Thinking about the problem",
            chat: .preview,
            withUserImage: false,
            withResponseImage: false,
            withFile: false
        )
        
        // Add additional channels for testing
        let commentaryChannel = Channel(
            type: .commentary,
            content: "Using web search",
            order: 1,
            recipient: "assistant"
        )
        commentaryChannel.message = message
        
        // Add commentary channel to existing channels
        var updatedChannels = message.channels ?? []
        updatedChannels.insert(commentaryChannel, at: 1) // Insert between analysis and final
        message.channels = updatedChannels
        
        // Tool calls are now stored as channels, not separately
        
        // Then - Verify storage
        #expect(message.channels != nil)
        #expect(message.channels?.count == 3)
        #expect(message.sortedChannels[0].type == .analysis)
        #expect(message.sortedChannels[1].type == .commentary)
        #expect(message.sortedChannels[2].type == .final)
        
        // Tool calls are now stored as channels
        
        // Verify computed properties work correctly
        #expect(message.response == "Here is the answer")
        #expect(message.thinking == "Thinking about the problem")
    }
    
    @Test("Message works without channels for backward compatibility")
    func testMessageWithoutChannels() {
        // When - Create message without channels using preview
        let message = Message.previewWithoutChannels
        
        // Then - Should work without channels
        #expect(message.channels == nil)
        // No separate tool calls storage
        #expect(message.response == nil) // Without channels, response is nil
        #expect(message.thinking == nil) // Without channels, thinking is nil
    }
    
    @Test("Message stores channels from ProcessedOutput")
    func testMessageFromProcessedOutput() {
        // Given - ProcessedOutput with channels including a tool channel
        let toolRequest = ToolRequest(
            name: "test_tool",
            arguments: "{\"key\": \"value\"}"
        )
        let processedOutput = ProcessedOutput(
            channels: [
                ChannelMessage(
                    id: UUID(),
                    type: .analysis,
                    content: "Analyzing...",
                    order: 0,
                    recipient: nil,
                    toolRequest: nil
                ),
                ChannelMessage(
                    id: UUID(),
                    type: .commentary,
                    content: "Processing...",
                    order: 1,
                    recipient: nil,
                    toolRequest: nil
                ),
                ChannelMessage(
                    id: UUID(),
                    type: .final,
                    content: "Final result",
                    order: 2,
                    recipient: nil,
                    toolRequest: nil
                ),
                ChannelMessage(
                    id: UUID(),
                    type: .tool,
                    content: "",
                    order: 3,
                    recipient: nil,
                    toolRequest: toolRequest
                )
            ]
        )
        
        // When - Converting to Channel entities
        let channels = processedOutput.channels.enumerated().map { index, channel in
            Channel(
                type: Channel.ChannelType(rawValue: channel.type.rawValue) ?? .final,
                content: channel.content,
                order: index
            )
        }
        
        // Tool requests are now extracted from channels
        let toolRequests = processedOutput.toolRequests
        
        // Then - Verify conversion
        #expect(channels.count == 4)
        #expect(channels[0].type == Channel.ChannelType.analysis)
        #expect(channels[0].content == "Analyzing...")
        #expect(channels[1].type == Channel.ChannelType.commentary)
        #expect(channels[1].content == "Processing...")
        #expect(channels[2].type == Channel.ChannelType.final)
        #expect(channels[2].content == "Final result")
        #expect(channels[3].type == Channel.ChannelType.tool)
        
        #expect(toolRequests.count == 1)
        #expect(toolRequests[0].name == "test_tool")
    }
    
    @Test("Channel entities preserve order")
    func testChannelEntitiesOrder() {
        // Given - Channels in specific order
        let channels = [
            Channel(type: .commentary, content: "Commentary", order: 1),
            Channel(type: .final, content: "Final", order: 2),
            Channel(type: .analysis, content: "Analysis", order: 0)
        ]
        
        // When - Sorting by order
        let sorted = channels.sorted { $0.order < $1.order }
        
        // Then - Should maintain order
        #expect(sorted[0].type == .analysis)
        #expect(sorted[0].order == 0)
        #expect(sorted[1].type == .commentary)
        #expect(sorted[1].order == 1)
        #expect(sorted[2].type == .final)
        #expect(sorted[2].order == 2)
    }
    
    // Test disabled during migration to new Tool architecture
    // @Test("Tool requests from channels")
    // func testToolRequestsFromChannels() throws {
    //     // Test implementation removed - migrating to new Tool architecture
    // }
}
