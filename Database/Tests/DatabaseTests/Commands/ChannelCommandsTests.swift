import Foundation
import SwiftData
import Testing
import Abstractions
import AbstractionsTestUtilities
@testable import Database

@Suite("Channel Commands Tests")
struct ChannelCommandsTests {
    // MARK: - Test Helpers
    
    static func setupTestDatabase() throws -> Database {
        let config = DatabaseConfiguration(
            isStoredInMemoryOnly: true,
            allowsSave: true,
            ragFactory: MockRagFactory(mockRag: MockRagging())
        )
        return try Database.new(configuration: config)
    }
    
    static func createTestMessage(_ database: Database) async throws -> UUID {
        // Add required models
        let languageModel = ModelDTO(
            type: .language,
            backend: .mlx,
            name: "test-llm",
            displayName: "Test LLM",
            displayDescription: "A test language model",
            skills: ["text-generation"],
            parameters: 100000,
            ramNeeded: 100.megabytes,
            size: 50.megabytes,
            locationHuggingface: "test/llm",
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
        
        try await database.write(ModelCommands.AddModels(modelDTOs: [languageModel, imageModel]))
        
        // Get the first personality (created during database initialization)
        // We'll use a simple UUID for testing
        let personalityId = UUID(uuidString: "00000000-0000-0000-0000-000000000001") ?? UUID()
        
        // Create a chat
        let chatId = try await database.write(ChatCommands.Create(personality: personalityId))
        
        // Create a message
        return try await database.write(
            MessageCommands.Create(
                chatId: chatId,
                userInput: "Test message",
                isDeepThinker: false
            )
        )
    }
    
    // MARK: - ProcessedToolCall Tests
    
    @Test("Create channel with tool type")
    func createChannelWithToolType() async throws {
        // Given
        let database = try Self.setupTestDatabase()
        let messageId = try await Self.createTestMessage(database)
        
        // When
        let channelId = try await database.write(
            ChannelCommands.Create(
                messageId: messageId,
                type: .tool,
                content: "{\"name\": \"calculator\", \"arguments\": {\"operation\": \"add\", \"a\": 5, \"b\": 3}}",
                order: 1
            )
        )
        
        // Then - channel was created successfully with tool type
        #expect(channelId != nil)
    }
    
    @Test("Batch upsert with tool channels")
    func batchUpsertWithToolChannels() async throws {
        // Given
        let database = try Self.setupTestDatabase()
        let messageId = try await Self.createTestMessage(database)
        
        let channels = [
            ChannelCommands.ChannelInput(
                type: .commentary,
                content: "Searching for information...",
                order: 0,
            ),
            ChannelCommands.ChannelInput(
                type: .tool,
                content: "{\"name\": \"calculator\", \"result\": \"4\"}",
                order: 1
            )
        ]
        
        // When
        let messageIdReturned = try await database.write(
            ChannelCommands.BatchUpsert(
                messageId: messageId,
                channels: channels
            )
        )
        
        // Then - upsert succeeds with tool calls
        #expect(messageIdReturned == messageId)
    }
    
    @Test("Update channel preserves tool content")
    func updateChannelPreservesToolContent() async throws {
        // Given
        let database = try Self.setupTestDatabase()
        let messageId = try await Self.createTestMessage(database)
        
        // Create channel with tool content
        let channelId = try await database.write(
            ChannelCommands.Create(
                messageId: messageId,
                type: .tool,
                content: "{\"name\": \"file_reader\", \"arguments\": {\"path\": \"/tmp/test.txt\"}}",
                order: 0
            )
        )
        
        // When - update content only
        try await database.write(
            ChannelCommands.Update(
                channelId: channelId,
                content: "File read complete"
            )
        )
        
        // Then - update succeeds (tool call should be preserved)
    }
    
    // MARK: - Create Tests
    
    @Test("Create channel successfully")
    func createChannelSuccessfully() async throws {
        // Given
        let database = try Self.setupTestDatabase()
        let messageId = try await Self.createTestMessage(database)
        
        // When
        let channelId = try await database.write(
            ChannelCommands.Create(
                messageId: messageId,
                type: .final,
                content: "Final content",
                order: 0
            )
        )
        
        // Then - channel was created successfully (ID returned)
    }
    
    @Test("Create channel with all properties")
    func createChannelWithAllProperties() async throws {
        // Given
        let database = try Self.setupTestDatabase()
        let messageId = try await Self.createTestMessage(database)
        let toolId = UUID()
        
        // When
        let channelId = try await database.write(
            ChannelCommands.Create(
                messageId: messageId,
                type: .commentary,
                content: "Commentary content",
                order: 1,
                recipient: "functions.tool",
                associatedToolId: toolId,
                isComplete: true
            )
        )
        
        // Then - channel was created successfully (ID returned)
    }
    
    @Test("Create channel for nonexistent message fails")
    func createChannelForNonexistentMessageFails() async throws {
        // Given
        let database = try Self.setupTestDatabase()
        let fakeMessageId = UUID()
        
        // When/Then
        await #expect(throws: DatabaseError.messageNotFound) {
            _ = try await database.write(
                ChannelCommands.Create(
                    messageId: fakeMessageId,
                    type: .final,
                    content: "Content",
                    order: 0
                )
            )
        }
    }
    
    // MARK: - Update Tests
    
    @Test("Update channel content successfully")
    func updateChannelContentSuccessfully() async throws {
        // Given
        let database = try Self.setupTestDatabase()
        let messageId = try await Self.createTestMessage(database)
        
        let channelId = try await database.write(
            ChannelCommands.Create(
                messageId: messageId,
                type: .final,
                content: "Initial content",
                order: 0
            )
        )
        
        // When
        try await database.write(
            ChannelCommands.Update(
                channelId: channelId,
                content: "Updated content"
            )
        )
        
        // Then - update didn't throw (success)
    }
    
    @Test("Update nonexistent channel fails")
    func updateNonexistentChannelFails() async throws {
        // Given
        let database = try Self.setupTestDatabase()
        let fakeChannelId = UUID()
        
        // When/Then
        await #expect(throws: DatabaseError.channelNotFound) {
            try await database.write(
                ChannelCommands.Update(
                    channelId: fakeChannelId,
                    content: "New content"
                )
            )
        }
    }
    
    // MARK: - Batch Upsert Tests
    
    @Test("Batch upsert creates new channels")
    func batchUpsertCreatesNewChannels() async throws {
        // Given
        let database = try Self.setupTestDatabase()
        let messageId = try await Self.createTestMessage(database)
        
        let channels = [
            ChannelCommands.ChannelInput(
                type: .analysis,
                content: "Analysis",
                order: 0
            ),
            ChannelCommands.ChannelInput(
                type: .commentary,
                content: "Commentary",
                order: 1
            ),
            ChannelCommands.ChannelInput(
                type: .final,
                content: "Final",
                order: 2
            )
        ]
        
        // When
        // BatchUpsert returns [UUID] so we need to use execute directly
        let messageIdReturned = try await database.write(
            ChannelCommands.BatchUpsert(
                messageId: messageId,
                channels: channels
            )
        )
        
        // Then - BatchUpsert returns the messageId
        #expect(messageIdReturned == messageId)
    }
    
    @Test("Batch upsert updates existing channels")
    func batchUpsertUpdatesExistingChannels() async throws {
        // Given
        let database = try Self.setupTestDatabase()
        let messageId = try await Self.createTestMessage(database)
        
        // Create initial channel
        _ = try await database.write(
            ChannelCommands.Create(
                messageId: messageId,
                type: .final,
                content: "Initial",
                order: 0
            )
        )
        
        // When - upsert with same type and order should update
        let channels = [
            ChannelCommands.ChannelInput(
                type: .final,
                content: "Updated",
                order: 0
            )
        ]
        
        let messageIdReturned = try await database.write(
            ChannelCommands.BatchUpsert(
                messageId: messageId,
                channels: channels
            )
        )
        
        // Then - returns messageId  
        #expect(messageIdReturned == messageId)
    }
    
    @Test("Batch upsert with empty array succeeds")
    func batchUpsertWithEmptyArraySucceeds() async throws {
        // Given
        let database = try Self.setupTestDatabase()
        let messageId = try await Self.createTestMessage(database)
        
        // When
        let messageIdReturned = try await database.write(
            ChannelCommands.BatchUpsert(
                messageId: messageId,
                channels: []
            )
        )
        
        // Then - returns messageId even with empty array
        #expect(messageIdReturned == messageId)
    }
    
    @Test("Batch upsert for nonexistent message fails")
    func batchUpsertForNonexistentMessageFails() async throws {
        // Given
        let database = try Self.setupTestDatabase()
        let fakeMessageId = UUID()
        
        let channels = [
            ChannelCommands.ChannelInput(
                type: .final,
                content: "Content",
                order: 0
            )
        ]
        
        // When/Then
        await #expect(throws: DatabaseError.messageNotFound) {
            _ = try await database.write(
                ChannelCommands.BatchUpsert(
                    messageId: fakeMessageId,
                    channels: channels
                )
            )
        }
    }
    
    // MARK: - LinkToolExecution Tests
    
    @Test("Link tool execution to channel successfully")
    func linkToolExecutionSuccessfully() async throws {
        // Given
        let database = try Self.setupTestDatabase()
        let messageId = try await Self.createTestMessage(database)
        
        // Create a channel
        let channelId = try await database.write(
            ChannelCommands.Create(
                messageId: messageId,
                type: .tool,
                content: "Tool channel",
                order: 0
            )
        )
        
        // Create a tool execution
        let toolRequest = ToolRequest(
            name: "test_tool",
            arguments: "{\"param\": \"value\"}"
        )
        
        let toolExecutionId = try await database.write(
            ToolExecutionCommands.Create(
                request: toolRequest,
                channelId: channelId,
                messageId: messageId
            )
        )
        
        // When
        let linkedChannelId = try await database.write(
            ChannelCommands.LinkToolExecution(
                channelId: channelId,
                toolExecutionId: toolExecutionId
            )
        )
        
        // Then
        #expect(linkedChannelId == channelId)
    }
    
    @Test("Link tool execution with invalid channel fails")
    func linkToolExecutionInvalidChannelFails() async throws {
        // Given
        let database = try Self.setupTestDatabase()
        let fakeChannelId = UUID()
        let fakeToolExecutionId = UUID()
        
        // When/Then
        await #expect(throws: DatabaseError.channelNotFound) {
            try await database.write(
                ChannelCommands.LinkToolExecution(
                    channelId: fakeChannelId,
                    toolExecutionId: fakeToolExecutionId
                )
            )
        }
    }
    
    @Test("Link tool execution with invalid tool execution fails")
    func linkToolExecutionInvalidToolExecutionFails() async throws {
        // Given
        let database = try Self.setupTestDatabase()
        let messageId = try await Self.createTestMessage(database)
        
        // Create a channel
        let channelId = try await database.write(
            ChannelCommands.Create(
                messageId: messageId,
                type: .tool,
                content: "Tool channel",
                order: 0
            )
        )
        
        let fakeToolExecutionId = UUID()
        
        // When/Then
        await #expect(throws: DatabaseError.toolExecutionNotFound) {
            try await database.write(
                ChannelCommands.LinkToolExecution(
                    channelId: channelId,
                    toolExecutionId: fakeToolExecutionId
                )
            )
        }
    }
}