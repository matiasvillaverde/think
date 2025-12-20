import Testing
import Foundation
import SwiftData
@testable import Database
import Abstractions
import AbstractionsTestUtilities

// MARK: - Helper Functions

private func setupTestDatabase() async throws -> Database {
    let config = DatabaseConfiguration(
        isStoredInMemoryOnly: true,
        allowsSave: true,
        ragFactory: MockRagFactory(mockRag: MockRagging())
    )
    
    let database = try Database.new(configuration: config)
    
    // Initialize default personality
    try await database.write(PersonalityCommands.WriteDefault())
    
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
    
    return database
}

@Suite("ToolExecutionCommands.Create Tests")
struct ToolExecutionCommandsCreateTests {
    @Test("Creates ToolExecution with pending state")
    @MainActor
    func testCreateToolExecutionWithPendingState() async throws {
        // Given
        let database = try await setupTestDatabase()
        let defaultPersonalityId = try await database.read(PersonalityCommands.GetDefault())
        
        // Create chat
        let chatId = try await database.write(
            ChatCommands.Create(personality: defaultPersonalityId)
        )
        
        // Create message
        try await database.write(MessageCommands.Create(
            chatId: chatId,
            userInput: "Test message",
            isDeepThinker: false
        ))
        
        let messages = try database.modelContainer.mainContext.fetch(
            FetchDescriptor<Message>()
        )
        let messageId = messages[0].id
        
        // When
        let request = ToolRequest(
            name: "test_tool",
            arguments: "{\"param\":\"value\"}",
            displayName: "Test Tool"
        )
        
        try await database.write(ToolExecutionCommands.Create(
            request: request,
            channelId: nil,
            messageId: messageId
        ))
        
        // Then
        let executions = try await database.read(
            ToolExecutionCommands.GetByMessage(messageId: messageId)
        )
        
        #expect(executions.count == 1)
        #expect(executions[0].toolName == "test_tool")
        #expect(executions[0].state == ToolExecutionState.pending)
        #expect(executions[0].request?.name == "test_tool")
        #expect(executions[0].request?.arguments == "{\"param\":\"value\"}")
    }
}

@Suite("ToolExecutionCommands.StartExecution Tests")
struct ToolExecutionCommandsStartExecutionTests {
    @Test("Updates ToolExecution state from pending to executing")
    @MainActor
    func testStartExecutionUpdatesPendingToExecuting() async throws {
        // Given
        let database = try await setupTestDatabase()
        let defaultPersonalityId = try await database.read(PersonalityCommands.GetDefault())
        
        // Create chat and message
        let chatId = try await database.write(
            ChatCommands.Create(personality: defaultPersonalityId)
        )
        
        try await database.write(MessageCommands.Create(
            chatId: chatId,
            userInput: "Test message",
            isDeepThinker: false
        ))
        
        let messages = try database.modelContainer.mainContext.fetch(
            FetchDescriptor<Message>()
        )
        let messageId = messages[0].id
        
        // Create a ToolExecution in pending state
        let request = ToolRequest(
            name: "test_tool",
            arguments: "{\"param\":\"value\"}",
            displayName: "Test Tool"
        )
        
        let executionId = try await database.write(ToolExecutionCommands.Create(
            request: request,
            channelId: nil,
            messageId: messageId
        ))
        
        // When
        try await database.write(ToolExecutionCommands.StartExecution(
            executionId: executionId
        ))
        
        // Then
        let executions = try await database.read(
            ToolExecutionCommands.GetByMessage(messageId: messageId)
        )
        
        #expect(executions.count == 1)
        #expect(executions[0].state == ToolExecutionState.executing)
        #expect(executions[0].startedAt != nil)
    }
    
    @Test("Throws error when ToolExecution not found")
    @MainActor
    func testStartExecutionThrowsWhenNotFound() async throws {
        // Given
        let database = try await setupTestDatabase()
        let nonExistentId = UUID()
        
        // When/Then
        await #expect(throws: DatabaseError.self) {
            try await database.write(ToolExecutionCommands.StartExecution(
                executionId: nonExistentId
            ))
        }
    }
    
    @Test("Throws error when already executing")
    @MainActor
    func testStartExecutionThrowsWhenAlreadyExecuting() async throws {
        // Given
        let database = try await setupTestDatabase()
        let defaultPersonalityId = try await database.read(PersonalityCommands.GetDefault())
        
        // Create chat and message
        let chatId = try await database.write(
            ChatCommands.Create(personality: defaultPersonalityId)
        )
        
        try await database.write(MessageCommands.Create(
            chatId: chatId,
            userInput: "Test message",
            isDeepThinker: false
        ))
        
        let messages = try database.modelContainer.mainContext.fetch(
            FetchDescriptor<Message>()
        )
        let messageId = messages[0].id
        
        // Create and start a ToolExecution
        let request = ToolRequest(
            name: "test_tool",
            arguments: "{\"param\":\"value\"}",
            displayName: "Test Tool"
        )
        
        let executionId = try await database.write(ToolExecutionCommands.Create(
            request: request,
            channelId: nil,
            messageId: messageId
        ))
        
        try await database.write(ToolExecutionCommands.StartExecution(
            executionId: executionId
        ))
        
        // When/Then - Try to start again
        await #expect(throws: DatabaseError.self) {
            try await database.write(ToolExecutionCommands.StartExecution(
                executionId: executionId
            ))
        }
    }
}

@Suite("ToolExecutionCommands.Complete Tests")
struct ToolExecutionCommandsCompleteTests {
    @Test("Updates ToolExecution state from executing to completed with response")
    @MainActor
    func testCompleteExecutionWithResponse() async throws {
        // Given
        let database = try await setupTestDatabase()
        let defaultPersonalityId = try await database.read(PersonalityCommands.GetDefault())
        
        // Create chat and message
        let chatId = try await database.write(
            ChatCommands.Create(personality: defaultPersonalityId)
        )
        
        try await database.write(MessageCommands.Create(
            chatId: chatId,
            userInput: "Test message",
            isDeepThinker: false
        ))
        
        let messages = try database.modelContainer.mainContext.fetch(
            FetchDescriptor<Message>()
        )
        let messageId = messages[0].id
        
        // Create and start a ToolExecution
        let request = ToolRequest(
            name: "test_tool",
            arguments: "{\"param\":\"value\"}",
            displayName: "Test Tool"
        )
        
        let executionId = try await database.write(ToolExecutionCommands.Create(
            request: request,
            channelId: nil,
            messageId: messageId
        ))
        
        try await database.write(ToolExecutionCommands.StartExecution(
            executionId: executionId
        ))
        
        // When
        let response = ToolResponse(
            requestId: request.id,
            toolName: "test_tool",
            result: "Tool executed successfully"
        )
        
        try await database.write(ToolExecutionCommands.Complete(
            executionId: executionId,
            response: response
        ))
        
        // Then
        let executions = try await database.read(
            ToolExecutionCommands.GetByMessage(messageId: messageId)
        )
        
        #expect(executions.count == 1)
        #expect(executions[0].state == ToolExecutionState.completed)
        #expect(executions[0].response?.result == "Tool executed successfully")
        #expect(executions[0].completedAt != nil)
    }
    
    @Test("Throws error when ToolExecution not found")
    @MainActor
    func testCompleteThrowsWhenNotFound() async throws {
        // Given
        let database = try await setupTestDatabase()
        let nonExistentId = UUID()
        
        let response = ToolResponse(
            requestId: nonExistentId,
            toolName: "test_tool",
            result: "Result"
        )
        
        // When/Then
        await #expect(throws: DatabaseError.self) {
            try await database.write(ToolExecutionCommands.Complete(
                executionId: nonExistentId,
                response: response
            ))
        }
    }
    
    @Test("Throws error when not in executing state")
    @MainActor
    func testCompleteThrowsWhenNotExecuting() async throws {
        // Given
        let database = try await setupTestDatabase()
        let defaultPersonalityId = try await database.read(PersonalityCommands.GetDefault())
        
        // Create chat and message
        let chatId = try await database.write(
            ChatCommands.Create(personality: defaultPersonalityId)
        )
        
        try await database.write(MessageCommands.Create(
            chatId: chatId,
            userInput: "Test message",
            isDeepThinker: false
        ))
        
        let messages = try database.modelContainer.mainContext.fetch(
            FetchDescriptor<Message>()
        )
        let messageId = messages[0].id
        
        // Create a ToolExecution but don't start it (stays in pending)
        let request = ToolRequest(
            name: "test_tool",
            arguments: "{\"param\":\"value\"}",
            displayName: "Test Tool"
        )
        
        let executionId = try await database.write(ToolExecutionCommands.Create(
            request: request,
            channelId: nil,
            messageId: messageId
        ))
        
        let response = ToolResponse(
            requestId: request.id,
            toolName: "test_tool",
            result: "Result"
        )
        
        // When/Then - Try to complete without starting
        await #expect(throws: (any Error).self) {
            try await database.write(ToolExecutionCommands.Complete(
                executionId: executionId,
                response: response
            ))
        }
    }
}

@Suite("ToolExecutionCommands.Fail Tests")
struct ToolExecutionCommandsFailTests {
    @Test("Updates ToolExecution state to failed with error message")
    @MainActor
    func testFailExecutionWithError() async throws {
        // Given
        let database = try await setupTestDatabase()
        let defaultPersonalityId = try await database.read(PersonalityCommands.GetDefault())
        
        // Create chat and message
        let chatId = try await database.write(
            ChatCommands.Create(personality: defaultPersonalityId)
        )
        
        try await database.write(MessageCommands.Create(
            chatId: chatId,
            userInput: "Test message",
            isDeepThinker: false
        ))
        
        let messages = try database.modelContainer.mainContext.fetch(
            FetchDescriptor<Message>()
        )
        let messageId = messages[0].id
        
        // Create and start a ToolExecution
        let request = ToolRequest(
            name: "test_tool",
            arguments: "{\"param\":\"value\"}",
            displayName: "Test Tool"
        )
        
        let executionId = try await database.write(ToolExecutionCommands.Create(
            request: request,
            channelId: nil,
            messageId: messageId
        ))
        
        try await database.write(ToolExecutionCommands.StartExecution(
            executionId: executionId
        ))
        
        // When
        let errorMessage = "Tool execution failed: Network error"
        try await database.write(ToolExecutionCommands.Fail(
            executionId: executionId,
            error: errorMessage
        ))
        
        // Then
        let executions = try await database.read(
            ToolExecutionCommands.GetByMessage(messageId: messageId)
        )
        
        #expect(executions.count == 1)
        #expect(executions[0].state == ToolExecutionState.failed)
        #expect(executions[0].errorMessage == errorMessage)
        #expect(executions[0].completedAt != nil)
        #expect(executions[0].response?.error == errorMessage)
    }
    
    @Test("Can fail from pending state")
    @MainActor
    func testFailFromPendingState() async throws {
        // Given
        let database = try await setupTestDatabase()
        let defaultPersonalityId = try await database.read(PersonalityCommands.GetDefault())
        
        // Create chat and message
        let chatId = try await database.write(
            ChatCommands.Create(personality: defaultPersonalityId)
        )
        
        try await database.write(MessageCommands.Create(
            chatId: chatId,
            userInput: "Test message",
            isDeepThinker: false
        ))
        
        let messages = try database.modelContainer.mainContext.fetch(
            FetchDescriptor<Message>()
        )
        let messageId = messages[0].id
        
        // Create a ToolExecution (stays in pending)
        let request = ToolRequest(
            name: "test_tool",
            arguments: "{\"param\":\"value\"}",
            displayName: "Test Tool"
        )
        
        let executionId = try await database.write(ToolExecutionCommands.Create(
            request: request,
            channelId: nil,
            messageId: messageId
        ))
        
        // When - Fail directly from pending
        let errorMessage = "Failed to parse tool arguments"
        try await database.write(ToolExecutionCommands.Fail(
            executionId: executionId,
            error: errorMessage
        ))
        
        // Then
        let executions = try await database.read(
            ToolExecutionCommands.GetByMessage(messageId: messageId)
        )
        
        #expect(executions.count == 1)
        #expect(executions[0].state == ToolExecutionState.failed)
        #expect(executions[0].errorMessage == errorMessage)
    }
    
    @Test("Throws error when ToolExecution not found")
    @MainActor
    func testFailThrowsWhenNotFound() async throws {
        // Given
        let database = try await setupTestDatabase()
        let nonExistentId = UUID()
        
        // When/Then
        await #expect(throws: DatabaseError.self) {
            try await database.write(ToolExecutionCommands.Fail(
                executionId: nonExistentId,
                error: "Error message"
            ))
        }
    }
}

@Suite("ToolExecutionCommands Read Commands Tests")
struct ToolExecutionCommandsReadTests {
    @Test("Get retrieves ToolExecution by ID")
    @MainActor
    func testGetByIdRetrievesExecution() async throws {
        // Given
        let database = try await setupTestDatabase()
        let defaultPersonalityId = try await database.read(PersonalityCommands.GetDefault())
        
        // Create chat and message
        let chatId = try await database.write(
            ChatCommands.Create(personality: defaultPersonalityId)
        )
        
        try await database.write(MessageCommands.Create(
            chatId: chatId,
            userInput: "Test message",
            isDeepThinker: false
        ))
        
        let messages = try database.modelContainer.mainContext.fetch(
            FetchDescriptor<Message>()
        )
        let messageId = messages[0].id
        
        // Create a ToolExecution
        let request = ToolRequest(
            name: "test_tool",
            arguments: "{\"param\":\"value\"}",
            displayName: "Test Tool"
        )
        
        let executionId = try await database.write(ToolExecutionCommands.Create(
            request: request,
            channelId: nil,
            messageId: messageId
        ))
        
        // When
        let execution = try await database.read(ToolExecutionCommands.Get(
            executionId: executionId
        ))
        
        // Then
        #expect(execution != nil)
        #expect(execution?.id == executionId)
        #expect(execution?.toolName == "test_tool")
    }
    
    @Test("Get returns nil when not found")
    @MainActor
    func testGetReturnsNilWhenNotFound() async throws {
        // Given
        let database = try await setupTestDatabase()
        let nonExistentId = UUID()
        
        // When
        let execution = try await database.read(ToolExecutionCommands.Get(
            executionId: nonExistentId
        ))
        
        // Then
        #expect(execution == nil)
    }
    
    @Test("GetByChannel retrieves ToolExecutions for specific channel")
    @MainActor
    func testGetByChannelRetrievesExecutions() async throws {
        // Given
        let database = try await setupTestDatabase()
        let defaultPersonalityId = try await database.read(PersonalityCommands.GetDefault())
        
        // Create chat and message
        let chatId = try await database.write(
            ChatCommands.Create(personality: defaultPersonalityId)
        )
        
        try await database.write(MessageCommands.Create(
            chatId: chatId,
            userInput: "Test message",
            isDeepThinker: false
        ))
        
        let messages = try database.modelContainer.mainContext.fetch(
            FetchDescriptor<Message>()
        )
        let messageId = messages[0].id
        
        // Create channel first
        let channelId = try await database.write(ChannelCommands.Create(
            messageId: messageId,
            type: .tool,
            content: "",
            order: 0
        ))
        
        // Create ToolExecutions with different channels
        let request1 = ToolRequest(
            name: "tool1",
            arguments: "{}",
            displayName: "Tool 1"
        )
        
        try await database.write(ToolExecutionCommands.Create(
            request: request1,
            channelId: channelId,
            messageId: messageId
        ))
        
        let request2 = ToolRequest(
            name: "tool2",
            arguments: "{}",
            displayName: "Tool 2"
        )
        
        try await database.write(ToolExecutionCommands.Create(
            request: request2,
            channelId: nil,
            messageId: messageId
        ))
        
        // When
        let executions = try await database.read(ToolExecutionCommands.GetByChannel(
            channelId: channelId
        ))
        
        // Then
        #expect(executions.count == 1)
        #expect(executions[0].toolName == "tool1")
    }
    
    @Test("GetPending retrieves only pending ToolExecutions")
    @MainActor
    func testGetPendingRetrievesOnlyPending() async throws {
        // Given
        let database = try await setupTestDatabase()
        let defaultPersonalityId = try await database.read(PersonalityCommands.GetDefault())
        
        // Create chat and message
        let chatId = try await database.write(
            ChatCommands.Create(personality: defaultPersonalityId)
        )
        
        try await database.write(MessageCommands.Create(
            chatId: chatId,
            userInput: "Test message",
            isDeepThinker: false
        ))
        
        let messages = try database.modelContainer.mainContext.fetch(
            FetchDescriptor<Message>()
        )
        let messageId = messages[0].id
        
        // Create multiple ToolExecutions with different states
        let request1 = ToolRequest(
            name: "pending_tool",
            arguments: "{}",
            displayName: "Pending Tool"
        )
        
        let pendingId = try await database.write(ToolExecutionCommands.Create(
            request: request1,
            channelId: nil,
            messageId: messageId
        ))
        
        let request2 = ToolRequest(
            name: "executing_tool",
            arguments: "{}",
            displayName: "Executing Tool"
        )
        
        let executingId = try await database.write(ToolExecutionCommands.Create(
            request: request2,
            channelId: nil,
            messageId: messageId
        ))
        
        try await database.write(ToolExecutionCommands.StartExecution(
            executionId: executingId
        ))
        
        // When
        let pendingExecutions = try await database.read(ToolExecutionCommands.GetPending())
        
        // Then
        #expect(pendingExecutions.count == 1)
        #expect(pendingExecutions[0].id == pendingId)
        #expect(pendingExecutions[0].state == .pending)
    }
    
    @Test("GetExecuting retrieves only executing ToolExecutions")
    @MainActor
    func testGetExecutingRetrievesOnlyExecuting() async throws {
        // Given
        let database = try await setupTestDatabase()
        let defaultPersonalityId = try await database.read(PersonalityCommands.GetDefault())
        
        // Create chat and message
        let chatId = try await database.write(
            ChatCommands.Create(personality: defaultPersonalityId)
        )
        
        try await database.write(MessageCommands.Create(
            chatId: chatId,
            userInput: "Test message",
            isDeepThinker: false
        ))
        
        let messages = try database.modelContainer.mainContext.fetch(
            FetchDescriptor<Message>()
        )
        let messageId = messages[0].id
        
        // Create multiple ToolExecutions with different states
        let request1 = ToolRequest(
            name: "pending_tool",
            arguments: "{}",
            displayName: "Pending Tool"
        )
        
        try await database.write(ToolExecutionCommands.Create(
            request: request1,
            channelId: nil,
            messageId: messageId
        ))
        
        let request2 = ToolRequest(
            name: "executing_tool",
            arguments: "{}",
            displayName: "Executing Tool"
        )
        
        let executingId = try await database.write(ToolExecutionCommands.Create(
            request: request2,
            channelId: nil,
            messageId: messageId
        ))
        
        try await database.write(ToolExecutionCommands.StartExecution(
            executionId: executingId
        ))
        
        // When
        let executingExecutions = try await database.read(ToolExecutionCommands.GetExecuting())
        
        // Then
        #expect(executingExecutions.count == 1)
        #expect(executingExecutions[0].id == executingId)
        #expect(executingExecutions[0].state == .executing)
    }
}