import Testing
import Foundation
import SwiftData
@testable import Database
import Abstractions
import AbstractionsTestUtilities

// MARK: - Helper Functions

private func addRequiredModelsForStreamingTest(_ database: Database) async throws {
    // Initialize default personality first
    try await database.write(PersonalityCommands.WriteDefault())
    
    let languageModel = ModelDTO(
        type: .language,
        backend: .mlx,
        name: "test-streaming-llm",
        displayName: "Test Streaming LLM",
        displayDescription: "A test language model for streaming",
        skills: ["text-generation"],
        parameters: 100000,
        ramNeeded: 100.megabytes,
        size: 50.megabytes,
        locationHuggingface: "test/streaming-llm",
        version: 1
    )

    let imageModel = ModelDTO(
        type: .diffusion,
        backend: .mlx,
        name: "test-image",
        displayName: "Test Image",
        displayDescription: "A test image model",
        skills: ["image-generation"],
        parameters: 50000,
        ramNeeded: 200.megabytes,
        size: 100.megabytes,
        locationHuggingface: "test/image",
        version: 1
    )

    try await database.write(ModelCommands.AddModels(models: [languageModel, imageModel]))
}

/// Comprehensive tests for UpdateProcessedOutput command focusing on streaming behavior
/// This is the core bug: UpdateProcessedOutput should accumulate channels across iterations,
/// not replace them. Critical for agentic loops where channels arrive in separate iterations.
@Suite("UpdateProcessedOutput Streaming Tests")
struct UpdateProcessedOutputStreamingTests {
    // MARK: - Single Channel Streaming Tests
    
    @Test("Single channel streaming - token by token updates")
    @MainActor
    func singleChannelTokenByToken() async throws {
        // Given
        let config = DatabaseConfiguration(
            isStoredInMemoryOnly: true,
            allowsSave: true,
            ragFactory: MockRagFactory(mockRag: MockRagging())
        )

        let database = try Database.new(configuration: config)
        try await addRequiredModelsForStreamingTest(database)
        let defaultPersonalityId = try await getDefaultPersonalityId(database)
        
        // Get the created model for chat association
        let models = try await database.read(ModelCommands.FetchAll())
        guard let testModel = models.first(where: { $0.modelType == .language }) else {
            #expect(Bool(false), "No language model found. Available models count: \(models.count)")
            return
        }
        
        let chatId = try await database.write(
            ChatCommands.CreateWithModel(
                modelId: testModel.id,
                personalityId: defaultPersonalityId
            )
        )

        let chat = try await database.read(ChatCommands.Read(chatId: chatId))
        try await database.write(MessageCommands.Create(
            chatId: chat.id,
            userInput: "Test streaming",
            isDeepThinker: false
        ))

        let descriptor = FetchDescriptor<Message>()
        let message = try database.modelContainer.mainContext.fetch(descriptor).first!
        
        // When - Simulate token-by-token streaming for single final channel
        let streamTokens = ["Hello", " world", "!", " This", " is", " streaming", " content."]
        var accumulatedContent = ""
        let channelId = UUID() // Same UUID across all streaming updates
        
        for token in streamTokens {
            accumulatedContent += token
            let output = ProcessedOutput(
                channels: [
                    ChannelMessage(
                        id: channelId,
                        type: .final,
                        content: accumulatedContent,
                        order: 0,
                        recipient: nil,
                        toolRequest: nil
                    )
                ]
            )
            try await database.write(MessageCommands.UpdateProcessedOutput(
                messageId: message.id,
                processedOutput: output
            ))
        }

        // Then - Should have 1 channel with complete content
        let updatedMessage = try database.modelContainer.mainContext.fetch(descriptor).first!
        #expect(updatedMessage.channels?.count == 1)
        #expect(updatedMessage.channels?.first?.content == "Hello world! This is streaming content.")
        #expect(updatedMessage.channels?.first?.type == .final)
    }
    
    // MARK: - Multi-Channel Agentic Flow Tests - THE CRITICAL BUG TESTS
    
    @Test("Agentic flow - commentary then final (should preserve both)")
    @MainActor
    func agenticFlowCommentaryThenFinal() async throws {
        // Given
        let config = DatabaseConfiguration(
            isStoredInMemoryOnly: true,
            allowsSave: true,
            ragFactory: MockRagFactory(mockRag: MockRagging())
        )

        let database = try Database.new(configuration: config)
        try await addRequiredModelsForStreamingTest(database)
        let defaultPersonalityId = try await getDefaultPersonalityId(database)
        
        // Get the created model for chat association
        let models = try await database.read(ModelCommands.FetchAll())
        let testModel = models.first(where: { $0.modelType == .language })!
        
        let chatId = try await database.write(
            ChatCommands.CreateWithModel(
                modelId: testModel.id,
                personalityId: defaultPersonalityId
            )
        )

        let chat = try await database.read(ChatCommands.Read(chatId: chatId))
        try await database.write(MessageCommands.Create(
            chatId: chat.id,
            userInput: "How many steps did I walk yesterday?",
            isDeepThinker: false
        ))

        let descriptor = FetchDescriptor<Message>()
        let message = try database.modelContainer.mainContext.fetch(descriptor).first!
        
        // When - Iteration 1: Commentary channel (simulating first LLM response)
        let commentaryChannelId = UUID() // Consistent UUID for commentary channel
        let commentaryOutput = ProcessedOutput(
            channels: [
                ChannelMessage(
                    id: commentaryChannelId,
                    type: .commentary,
                    content: "I'll check your step count from yesterday's health data.",
                    order: 0,
                    recipient: nil,
                    toolRequest: nil
                )
            ]
        )
        try await database.write(MessageCommands.UpdateProcessedOutput(
            messageId: message.id,
            processedOutput: commentaryOutput
        ))
        
        // Verify commentary is saved
        var updatedMessage = try database.modelContainer.mainContext.fetch(descriptor).first!
        #expect(updatedMessage.channels?.count == 1)
        #expect(updatedMessage.channels?.first?.type == .commentary)
        
        // When - Iteration 2: Final channel (simulating second LLM response after tool execution)
        let finalChannelId = UUID() // Consistent UUID for final channel
        let finalOutput = ProcessedOutput(
            channels: [
                ChannelMessage(
                    id: finalChannelId,
                    type: .final,
                    content: "According to your health data, you walked 8,543 steps yesterday!",
                    order: 1,
                    recipient: nil,
                    toolRequest: nil
                )
            ]
        )
        try await database.write(MessageCommands.UpdateProcessedOutput(
            messageId: message.id,
            processedOutput: finalOutput
        ))

        // Then - CRITICAL: Should have BOTH channels, not just final
        updatedMessage = try database.modelContainer.mainContext.fetch(descriptor).first!
        #expect(updatedMessage.channels?.count == 2, "Should preserve both commentary AND final channels")
        
        let sortedChannels = updatedMessage.sortedChannels
        #expect(sortedChannels[0].type == .commentary, "First channel should be commentary")
        #expect(sortedChannels[0].content == "I'll check your step count from yesterday's health data.")
        #expect(sortedChannels[1].type == .final, "Second channel should be final")
        #expect(sortedChannels[1].content == "According to your health data, you walked 8,543 steps yesterday!")
    }
    
    @Test("Agentic flow - commentary, tool, then final (full agentic scenario)")
    @MainActor
    func agenticFlowCommentaryToolFinal() async throws {
        // Given
        let config = DatabaseConfiguration(
            isStoredInMemoryOnly: true,
            allowsSave: true,
            ragFactory: MockRagFactory(mockRag: MockRagging())
        )

        let database = try Database.new(configuration: config)
        try await addRequiredModelsForStreamingTest(database)
        let defaultPersonalityId = try await getDefaultPersonalityId(database)
        
        // Get the created model for chat association
        let models = try await database.read(ModelCommands.FetchAll())
        let testModel = models.first(where: { $0.modelType == .language })!
        
        let chatId = try await database.write(
            ChatCommands.CreateWithModel(
                modelId: testModel.id,
                personalityId: defaultPersonalityId
            )
        )

        let chat = try await database.read(ChatCommands.Read(chatId: chatId))
        try await database.write(MessageCommands.Create(
            chatId: chat.id,
            userInput: "How many steps did I walk yesterday?",
            isDeepThinker: false
        ))

        let descriptor = FetchDescriptor<Message>()
        let message = try database.modelContainer.mainContext.fetch(descriptor).first!
        
        // When - Iteration 1: Commentary + Tool channels (first LLM response)
        let commentaryChannelId = UUID() // Consistent UUID for commentary channel
        let toolChannelId = UUID() // Consistent UUID for tool channel
        let firstIterationOutput = ProcessedOutput(
            channels: [
                ChannelMessage(
                    id: commentaryChannelId,
                    type: .commentary,
                    content: "I'll check your step count from yesterday's health data.",
                    order: 0,
                    recipient: nil,
                    toolRequest: nil
                ),
                ChannelMessage(
                    id: toolChannelId,
                    type: .tool,
                    content: "",
                    order: 1,
                    recipient: "health_data",
                    toolRequest: ToolRequest(
                        name: "health_data",
                        arguments: "{\"metric\": \"steps\", \"date\": \"yesterday\"}"
                    )
                )
            ]
        )
        try await database.write(MessageCommands.UpdateProcessedOutput(
            messageId: message.id,
            processedOutput: firstIterationOutput
        ))
        
        // Verify first iteration is saved
        var updatedMessage = try database.modelContainer.mainContext.fetch(descriptor).first!
        #expect(updatedMessage.channels?.count == 2, "Should have commentary and tool channels")
        
        // When - Iteration 2: Final channel only (second LLM response after tool execution)
        let finalChannelId = UUID() // Consistent UUID for final channel
        let finalIterationOutput = ProcessedOutput(
            channels: [
                ChannelMessage(
                    id: finalChannelId,
                    type: .final,
                    content: "According to your health data, you walked 8,543 steps yesterday!",
                    order: 2,
                    recipient: nil,
                    toolRequest: nil
                )
            ]
        )
        try await database.write(MessageCommands.UpdateProcessedOutput(
            messageId: message.id,
            processedOutput: finalIterationOutput
        ))

        // Then - CRITICAL: Should have ALL THREE channels
        updatedMessage = try database.modelContainer.mainContext.fetch(descriptor).first!
        #expect(updatedMessage.channels?.count == 3, "Should preserve commentary, tool, AND final channels")
        
        let sortedChannels = updatedMessage.sortedChannels
        #expect(sortedChannels[0].type == .commentary, "First channel should be commentary")
        #expect(sortedChannels[0].content == "I'll check your step count from yesterday's health data.")
        #expect(sortedChannels[1].type == .tool, "Second channel should be tool")
        #expect(sortedChannels[1].recipient == "health_data")
        #expect(sortedChannels[2].type == .final, "Third channel should be final")
        #expect(sortedChannels[2].content == "According to your health data, you walked 8,543 steps yesterday!")
    }
    
    // MARK: - Complex Streaming Scenarios
    
    @Test("Complex streaming - 50 channels of different types")
    @MainActor
    func complexStreaming50Channels() async throws {
        // Given
        let config = DatabaseConfiguration(
            isStoredInMemoryOnly: true,
            allowsSave: true,
            ragFactory: MockRagFactory(mockRag: MockRagging())
        )

        let database = try Database.new(configuration: config)
        try await addRequiredModelsForStreamingTest(database)
        let defaultPersonalityId = try await getDefaultPersonalityId(database)
        
        // Get the created model for chat association
        let models = try await database.read(ModelCommands.FetchAll())
        let testModel = models.first(where: { $0.modelType == .language })!
        
        let chatId = try await database.write(
            ChatCommands.CreateWithModel(
                modelId: testModel.id,
                personalityId: defaultPersonalityId
            )
        )

        let chat = try await database.read(ChatCommands.Read(chatId: chatId))
        try await database.write(MessageCommands.Create(
            chatId: chat.id,
            userInput: "Complex multi-channel test",
            isDeepThinker: false
        ))

        let descriptor = FetchDescriptor<Message>()
        let message = try database.modelContainer.mainContext.fetch(descriptor).first!
        
        // When - Create 50 channels in batches (simulating complex agentic flow)
        var expectedChannels: [ChannelMessage] = []
        
        // Batch 1: 20 analysis channels
        var batch1Channels: [ChannelMessage] = []
        for index in 0..<20 {
            let analysisChannelId = UUID() // Each analysis channel gets its own consistent UUID
            let channel = ChannelMessage(
                id: analysisChannelId,
                type: .analysis,
                content: "Analysis step \(index + 1)",
                order: index,
                recipient: nil,
                toolRequest: nil
            )
            batch1Channels.append(channel)
            expectedChannels.append(channel)
        }
        
        let batch1Output = ProcessedOutput(channels: batch1Channels)
        try await database.write(MessageCommands.UpdateProcessedOutput(
            messageId: message.id,
            processedOutput: batch1Output
        ))
        
        // Batch 2: 15 commentary channels
        var batch2Channels: [ChannelMessage] = []
        for index in 20..<35 {
            let commentaryChannelId = UUID() // Each commentary channel gets its own consistent UUID
            let channel = ChannelMessage(
                id: commentaryChannelId,
                type: .commentary,
                content: "Commentary step \(index + 1)",
                order: index,
                recipient: nil,
                toolRequest: nil
            )
            batch2Channels.append(channel)
            expectedChannels.append(channel)
        }
        
        let batch2Output = ProcessedOutput(channels: batch2Channels)
        try await database.write(MessageCommands.UpdateProcessedOutput(
            messageId: message.id,
            processedOutput: batch2Output
        ))
        
        // Batch 3: 10 tool channels
        var batch3Channels: [ChannelMessage] = []
        for index in 35..<45 {
            let toolChannelId = UUID() // Each tool channel gets its own consistent UUID
            let channel = ChannelMessage(
                id: toolChannelId,
                type: .tool,
                content: "",
                order: index,
                recipient: "tool_\(index)",
                toolRequest: ToolRequest(
                    name: "tool_\(index)",
                    arguments: "{\"step\": \(index)}"
                )
            )
            batch3Channels.append(channel)
            expectedChannels.append(channel)
        }
        
        let batch3Output = ProcessedOutput(channels: batch3Channels)
        try await database.write(MessageCommands.UpdateProcessedOutput(
            messageId: message.id,
            processedOutput: batch3Output
        ))
        
        // Batch 4: 5 final channels
        var batch4Channels: [ChannelMessage] = []
        for index in 45..<50 {
            let finalChannelId = UUID() // Each final channel gets its own consistent UUID
            let channel = ChannelMessage(
                id: finalChannelId,
                type: .final,
                content: "Final result \(index + 1)",
                order: index,
                recipient: nil,
                toolRequest: nil
            )
            batch4Channels.append(channel)
            expectedChannels.append(channel)
        }
        
        let batch4Output = ProcessedOutput(channels: batch4Channels)
        try await database.write(MessageCommands.UpdateProcessedOutput(
            messageId: message.id,
            processedOutput: batch4Output
        ))

        // Then - Should have ALL 50 channels preserved
        let updatedMessage = try database.modelContainer.mainContext.fetch(descriptor).first!
        #expect(updatedMessage.channels?.count == 50, "Should preserve all 50 channels across batches")
        
        let sortedChannels = updatedMessage.sortedChannels
        
        // Verify all analysis channels are preserved
        let analysisChannels = sortedChannels.filter { $0.type == .analysis }
        #expect(analysisChannels.count == 20, "Should have all 20 analysis channels")
        
        // Verify all commentary channels are preserved  
        let commentaryChannels = sortedChannels.filter { $0.type == .commentary }
        #expect(commentaryChannels.count == 15, "Should have all 15 commentary channels")
        
        // Verify all tool channels are preserved
        let toolChannels = sortedChannels.filter { $0.type == .tool }
        #expect(toolChannels.count == 10, "Should have all 10 tool channels")
        
        // Verify all final channels are preserved
        let finalChannels = sortedChannels.filter { $0.type == .final }
        #expect(finalChannels.count == 5, "Should have all 5 final channels")
        
        // Verify order is preserved
        for (index, channel) in sortedChannels.enumerated() {
            #expect(channel.order == index, "Channel order should be preserved")
        }
    }
    
    // MARK: - Edge Cases
    
    @Test("Same channel type different orders - should preserve both")
    @MainActor
    func sameChannelTypeDifferentOrders() async throws {
        // Given
        let config = DatabaseConfiguration(
            isStoredInMemoryOnly: true,
            allowsSave: true,
            ragFactory: MockRagFactory(mockRag: MockRagging())
        )

        let database = try Database.new(configuration: config)
        try await addRequiredModelsForStreamingTest(database)
        let defaultPersonalityId = try await getDefaultPersonalityId(database)
        
        // Get the created model for chat association
        let models = try await database.read(ModelCommands.FetchAll())
        let testModel = models.first(where: { $0.modelType == .language })!
        
        let chatId = try await database.write(
            ChatCommands.CreateWithModel(
                modelId: testModel.id,
                personalityId: defaultPersonalityId
            )
        )

        let chat = try await database.read(ChatCommands.Read(chatId: chatId))
        try await database.write(MessageCommands.Create(
            chatId: chat.id,
            userInput: "Multiple final channels test",
            isDeepThinker: false
        ))

        let descriptor = FetchDescriptor<Message>()
        let message = try database.modelContainer.mainContext.fetch(descriptor).first!
        
        // When - First batch: final channel order 0
        let firstFinalChannelId = UUID() // Consistent UUID for first final channel
        let firstOutput = ProcessedOutput(
            channels: [
                ChannelMessage(
                    id: firstFinalChannelId,
                    type: .final,
                    content: "First final response",
                    order: 0,
                    recipient: nil,
                    toolRequest: nil
                )
            ]
        )
        try await database.write(MessageCommands.UpdateProcessedOutput(
            messageId: message.id,
            processedOutput: firstOutput
        ))
        
        // When - Second batch: final channel order 1
        let secondFinalChannelId = UUID() // Consistent UUID for second final channel
        let secondOutput = ProcessedOutput(
            channels: [
                ChannelMessage(
                    id: secondFinalChannelId,
                    type: .final,
                    content: "Second final response",
                    order: 1,
                    recipient: nil,
                    toolRequest: nil
                )
            ]
        )
        try await database.write(MessageCommands.UpdateProcessedOutput(
            messageId: message.id,
            processedOutput: secondOutput
        ))

        // Then - Should have both final channels with different orders
        let updatedMessage = try database.modelContainer.mainContext.fetch(descriptor).first!
        #expect(updatedMessage.channels?.count == 2, "Should have both final channels")
        
        let finalChannels = updatedMessage.channels?.filter { $0.type == .final } ?? []
        #expect(finalChannels.count == 2, "Should have 2 final channels with different orders")
        
        let sortedFinals = finalChannels.sorted { $0.order < $1.order }
        #expect(sortedFinals[0].content == "First final response")
        #expect(sortedFinals[1].content == "Second final response")
    }
    
    @Test("Empty channels array - should not affect existing channels")
    @MainActor
    func emptyChannelsArrayShouldNotAffectExisting() async throws {
        // Given
        let config = DatabaseConfiguration(
            isStoredInMemoryOnly: true,
            allowsSave: true,
            ragFactory: MockRagFactory(mockRag: MockRagging())
        )

        let database = try Database.new(configuration: config)
        try await addRequiredModelsForStreamingTest(database)
        let defaultPersonalityId = try await getDefaultPersonalityId(database)
        
        // Get the created model for chat association
        let models = try await database.read(ModelCommands.FetchAll())
        let testModel = models.first(where: { $0.modelType == .language })!
        
        let chatId = try await database.write(
            ChatCommands.CreateWithModel(
                modelId: testModel.id,
                personalityId: defaultPersonalityId
            )
        )

        let chat = try await database.read(ChatCommands.Read(chatId: chatId))
        try await database.write(MessageCommands.Create(
            chatId: chat.id,
            userInput: "Empty channels test",
            isDeepThinker: false
        ))

        let descriptor = FetchDescriptor<Message>()
        let message = try database.modelContainer.mainContext.fetch(descriptor).first!
        
        // When - First: Add some channels
        let initialCommentaryChannelId = UUID() // Consistent UUID for initial commentary channel
        let initialFinalChannelId = UUID() // Consistent UUID for initial final channel
        let initialOutput = ProcessedOutput(
            channels: [
                ChannelMessage(
                    id: initialCommentaryChannelId,
                    type: .commentary,
                    content: "Initial comment",
                    order: 0,
                    recipient: nil,
                    toolRequest: nil
                ),
                ChannelMessage(
                    id: initialFinalChannelId,
                    type: .final,
                    content: "Initial final",
                    order: 1,
                    recipient: nil,
                    toolRequest: nil
                )
            ]
        )
        try await database.write(MessageCommands.UpdateProcessedOutput(
            messageId: message.id,
            processedOutput: initialOutput
        ))
        
        // When - Second: Empty channels array
        let emptyOutput = ProcessedOutput(channels: [])
        try await database.write(MessageCommands.UpdateProcessedOutput(
            messageId: message.id,
            processedOutput: emptyOutput
        ))

        // Then - Should still have original channels
        let updatedMessage = try database.modelContainer.mainContext.fetch(descriptor).first!
        #expect(updatedMessage.channels?.count == 2, "Empty update should not remove existing channels")
        
        let sortedChannels = updatedMessage.sortedChannels
        #expect(sortedChannels[0].type == .commentary)
        #expect(sortedChannels[0].content == "Initial comment")
        #expect(sortedChannels[1].type == .final)
        #expect(sortedChannels[1].content == "Initial final")
    }
}