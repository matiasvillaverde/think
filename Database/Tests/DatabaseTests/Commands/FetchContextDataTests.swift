import Testing
import Foundation
import SwiftData
import Abstractions
import DataAssets
@testable import Database
import AbstractionsTestUtilities

@Suite("FetchContextData Command Tests")
struct FetchContextDataTests {
    @Test("Fetch context data for empty chat")
    @MainActor
    func fetchContextEmptyChat() async throws {
        // Given
        let config = DatabaseConfiguration(
            isStoredInMemoryOnly: true,
            allowsSave: true,
            ragFactory: MockRagFactory(mockRag: MockRagging())
        )
        
        let database = try Database.new(configuration: config)
        try await addRequiredModelsForChatCommands(database)
        let defaultPersonalityId = try await getDefaultPersonalityId(database)
        let chatId = try await database.write(ChatCommands.Create(personality: defaultPersonalityId))
        
        // When
        let context = try await database.read(ChatCommands.FetchContextData(chatId: chatId))
        
        // Then
        #expect(context.systemInstruction == SystemInstruction.empatheticFriend.rawValue)
        #expect(context.contextMessages.isEmpty)
        #expect(context.maxPrompt == 10240)
        #expect(context.includeCurrentDate == true) // Default is true
        #expect(context.knowledgeCutoffDate == nil) // Default is nil
        #expect(context.currentDateOverride == nil) // Default is nil
    }
    
    @Test("Fetch context data with messages")
    @MainActor
    func fetchContextWithMessages() async throws {
        // Given
        let config = DatabaseConfiguration(
            isStoredInMemoryOnly: true,
            allowsSave: true,
            ragFactory: MockRagFactory(mockRag: MockRagging())
        )
        
        let database = try Database.new(configuration: config)
        try await addRequiredModelsForChatCommands(database)
        let defaultPersonalityId = try await getDefaultPersonalityId(database)
        let chatId = try await database.write(ChatCommands.Create(personality: defaultPersonalityId))
        
        // Add first message with response
        let messageId1 = try await database.write(MessageCommands.Create(
            chatId: chatId,
            userInput: "Hello, how are you?",
            isDeepThinker: false
        ))
        
        // Add response as channel to first message
        let message1 = try await database.read(MessageCommands.Read(id: messageId1))
        let finalChannel1 = Channel(type: .final, content: "I'm doing well, thank you!", order: 0)
        finalChannel1.message = message1
        message1.channels = [finalChannel1]
        database.modelContainer.mainContext.insert(finalChannel1)
        try database.modelContainer.mainContext.save()
        
        // Add second message with response
        let messageId2 = try await database.write(MessageCommands.Create(
            chatId: chatId,
            userInput: "What's the weather like?",
            isDeepThinker: false
        ))
        
        // Add response as channel to second message
        let message2 = try await database.read(MessageCommands.Read(id: messageId2))
        let finalChannel2 = Channel(type: .final, content: "I don't have access to real-time weather data.", order: 0)
        finalChannel2.message = message2
        message2.channels = [finalChannel2]
        database.modelContainer.mainContext.insert(finalChannel2)
        try database.modelContainer.mainContext.save()
        
        // When
        let context = try await database.read(ChatCommands.FetchContextData(chatId: chatId))
        
        // Then
        #expect(context.contextMessages.count == 2)
        #expect(context.contextMessages[0].userInput == "Hello, how are you?")
        #expect(context.contextMessages[0].channels.count == 1)
        #expect(context.contextMessages[0].channels[0].type == .final)
        #expect(context.contextMessages[0].channels[0].content == "I'm doing well, thank you!")
        #expect(context.contextMessages[1].userInput == "What's the weather like?")
        #expect(context.contextMessages[1].channels.count == 1)
        #expect(context.contextMessages[1].channels[0].type == .final)
        #expect(context.contextMessages[1].channels[0].content == "I don't have access to real-time weather data.")
    }
    
    @Test("Fetch context for nonexistent chat fails")
    @MainActor
    func fetchContextNonexistentChat() async throws {
        // Given
        let config = DatabaseConfiguration(
            isStoredInMemoryOnly: true,
            allowsSave: true,
            ragFactory: MockRagFactory(mockRag: MockRagging())
        )
        
        let database = try Database.new(configuration: config)
        let nonexistentId = UUID()
        
        // When/Then
        await #expect(throws: DatabaseError.chatNotFound) {
            try await database.read(ChatCommands.FetchContextData(chatId: nonexistentId))
        }
    }
    
    @Test("Fetch context preserves message order")
    @MainActor
    func fetchContextMessageOrder() async throws {
        // Given
        let config = DatabaseConfiguration(
            isStoredInMemoryOnly: true,
            allowsSave: true,
            ragFactory: MockRagFactory(mockRag: MockRagging())
        )
        
        let database = try Database.new(configuration: config)
        try await addRequiredModelsForChatCommands(database)
        let defaultPersonalityId = try await getDefaultPersonalityId(database)
        let chatId = try await database.write(ChatCommands.Create(personality: defaultPersonalityId))
        
        // Add multiple messages
        var messageIds: [UUID] = []
        for num in 1...3 {
            let messageId = try await database.write(MessageCommands.Create(
                chatId: chatId,
                userInput: "Message \(num)",
                isDeepThinker: false
            ))
            messageIds.append(messageId)
            
            // Add response as channel
            let message = try await database.read(MessageCommands.Read(id: messageId))
            let finalChannel = Channel(type: .final, content: "Response \(num)", order: 0)
            finalChannel.message = message
            message.channels = [finalChannel]
            database.modelContainer.mainContext.insert(finalChannel)
            try database.modelContainer.mainContext.save()
            
            // Small delay to ensure different timestamps
            try await Task.sleep(nanoseconds: 10_000_000) // 10ms
        }
        
        // When
        let context = try await database.read(ChatCommands.FetchContextData(chatId: chatId))
        
        // Then
        #expect(context.contextMessages.count == 3)
        for (index, message) in context.contextMessages.enumerated() {
            #expect(message.userInput == "Message \(index + 1)")
            #expect(message.channels.count == 1)
            #expect(message.channels[0].type == .final)
            #expect(message.channels[0].content == "Response \(index + 1)")
        }
        
        // Verify chronological order
        for idx in 1..<context.contextMessages.count {
            #expect(context.contextMessages[idx-1].createdAt <= context.contextMessages[idx].createdAt)
        }
    }
    
    @Test("Fetch context data includes tool calls from tool executions")
    @MainActor
    func fetchContextWithToolCalls() async throws {
        // Given
        let config = DatabaseConfiguration(
            isStoredInMemoryOnly: true,
            allowsSave: true,
            ragFactory: MockRagFactory(mockRag: MockRagging())
        )
        
        let database = try Database.new(configuration: config)
        try await addRequiredModelsForChatCommands(database)
        let defaultPersonalityId = try await getDefaultPersonalityId(database)
        let chatId = try await database.write(ChatCommands.Create(personality: defaultPersonalityId))
        
        // Create a message with user input and assistant response
        let messageId = try await database.write(MessageCommands.Create(
            chatId: chatId,
            userInput: "What's the weather in Berlin?",
            isDeepThinker: false
        ))
        
        let message = try await database.read(MessageCommands.Read(id: messageId))
        
        // Add assistant response channel (order 0)
        let assistantChannel = Channel(
            type: .final,
            content: "I'll check the weather in Berlin for you.",
            order: 0
        )
        assistantChannel.message = message
        database.modelContainer.mainContext.insert(assistantChannel)
        
        // Create tool channel with tool execution (order 1)
        let toolChannel = Channel(
            type: .tool,
            content: "Tool execution channel",
            order: 1
        )
        toolChannel.message = message
        database.modelContainer.mainContext.insert(toolChannel)
        
        // Create tool execution with weather tool request
        let toolRequest = ToolRequest(
            name: "weather",
            arguments: "{\"city\": \"Berlin\"}",
            displayName: "Weather Tool"
        )
        
        let toolExecution = ToolExecution(
            request: toolRequest,
            state: .completed,
            channel: toolChannel
        )
        
        // Link the tool execution to the channel
        toolChannel.toolExecution = toolExecution
        database.modelContainer.mainContext.insert(toolExecution)
        
        // Create another tool channel with different tool (order 2)
        let browserChannel = Channel(
            type: .tool,
            content: "Browser tool execution",
            order: 2
        )
        browserChannel.message = message
        database.modelContainer.mainContext.insert(browserChannel)
        
        let browserRequest = ToolRequest(
            name: "browser.search",
            arguments: "{\"query\": \"weather Berlin\", \"max_results\": 3}",
            displayName: "Browser Search"
        )
        
        let browserExecution = ToolExecution(
            request: browserRequest,
            state: .completed,
            channel: browserChannel
        )
        
        browserChannel.toolExecution = browserExecution
        database.modelContainer.mainContext.insert(browserExecution)
        
        // Update message channels
        message.channels = [assistantChannel, toolChannel, browserChannel]
        try database.modelContainer.mainContext.save()
        
        // When
        let context = try await database.read(ChatCommands.FetchContextData(chatId: chatId))
        
        // Then
        #expect(context.contextMessages.count == 1)
        
        let messageData = context.contextMessages[0]
        #expect(messageData.userInput == "What's the weather in Berlin?")
        #expect(messageData.channels.count == 1)
        #expect(messageData.channels[0].type == .final)
        #expect(messageData.channels[0].content == "I'll check the weather in Berlin for you.")
        
        // Verify tool calls are properly extracted and ordered
        #expect(messageData.toolCalls.count == 2)
        
        // First tool call (order 1)
        let firstToolCall = messageData.toolCalls[0]
        #expect(firstToolCall.name == "weather")
        #expect(firstToolCall.arguments == "{\"city\": \"Berlin\"}")
        #expect(firstToolCall.id == toolRequest.id.uuidString)
        
        // Second tool call (order 2)  
        let secondToolCall = messageData.toolCalls[1]
        #expect(secondToolCall.name == "browser.search")
        #expect(secondToolCall.arguments == "{\"query\": \"weather Berlin\", \"max_results\": 3}")
        #expect(secondToolCall.id == browserRequest.id.uuidString)
    }
    
    @Test("Fetch context data handles messages without tool calls")
    @MainActor
    func fetchContextWithoutToolCalls() async throws {
        // Given
        let config = DatabaseConfiguration(
            isStoredInMemoryOnly: true,
            allowsSave: true,
            ragFactory: MockRagFactory(mockRag: MockRagging())
        )
        
        let database = try Database.new(configuration: config)
        try await addRequiredModelsForChatCommands(database)
        let defaultPersonalityId = try await getDefaultPersonalityId(database)
        let chatId = try await database.write(ChatCommands.Create(personality: defaultPersonalityId))
        
        // Create a regular message without tool channels
        let messageId = try await database.write(MessageCommands.Create(
            chatId: chatId,
            userInput: "Hello there!",
            isDeepThinker: false
        ))
        
        let message = try await database.read(MessageCommands.Read(id: messageId))
        let finalChannel = Channel(type: .final, content: "Here is a response.", order: 0)
        finalChannel.message = message
        message.channels = [finalChannel]
        database.modelContainer.mainContext.insert(finalChannel)
        try database.modelContainer.mainContext.save()
        
        // When
        let context = try await database.read(ChatCommands.FetchContextData(chatId: chatId))
        
        // Then
        #expect(context.contextMessages.count == 1)
        
        let messageData = context.contextMessages[0]
        #expect(messageData.userInput == "Hello there!")
        #expect(messageData.channels.count == 1)
        #expect(messageData.channels[0].type == .final)
        #expect(messageData.channels[0].content == "Here is a response.")
        #expect(messageData.toolCalls.isEmpty) // Should be empty array, not nil
    }
    
    @Test("FetchTableName returns correct format with t_ prefix and uppercase UUID")
    @MainActor
    func fetchTableNameFormat() async throws {
        // Given
        let config = DatabaseConfiguration(
            isStoredInMemoryOnly: true,
            allowsSave: true,
            ragFactory: MockRagFactory(mockRag: MockRagging())
        )
        
        let database = try Database.new(configuration: config)
        try await addRequiredModelsForChatCommands(database)
        let defaultPersonalityId = try await getDefaultPersonalityId(database)
        let chatId = try await database.write(ChatCommands.Create(personality: defaultPersonalityId))
        
        // When
        let tableName = try await database.read(ChatCommands.FetchTableName(chatId: chatId))
        
        // Then
        // Verify format: should be "t_" + uppercase UUID with underscores
        #expect(tableName.hasPrefix("t_"))
        
        // Extract the UUID part after "t_"
        let uuidPart = String(tableName.dropFirst(2))
        
        // Verify the UUID part is uppercase
        #expect(uuidPart == uuidPart.uppercased())
        
        // Verify underscores replace hyphens (UUID format check)
        #expect(uuidPart.contains("_"))
        #expect(!uuidPart.contains("-"))
        
        // Verify the table name matches what generateTableName() would produce
        let chat = try await database.read(ChatCommands.Read(chatId: chatId))
        let expectedTableName = chat.generateTableName()
        #expect(tableName == expectedTableName)
        
        // Verify exact format with the original UUID
        let expectedFormat = "t_\(chatId.uuidString.uppercased().replacingOccurrences(of: "-", with: "_"))"
        #expect(tableName == expectedFormat)
    }
    
    @Test("FetchTableName consistency with Chat.generateTableName")
    @MainActor
    func fetchTableNameConsistency() async throws {
        // Given
        let config = DatabaseConfiguration(
            isStoredInMemoryOnly: true,
            allowsSave: true,
            ragFactory: MockRagFactory(mockRag: MockRagging())
        )
        
        let database = try Database.new(configuration: config)
        try await addRequiredModelsForChatCommands(database)
        let defaultPersonalityId = try await getDefaultPersonalityId(database)
        
        // Create multiple chats to test consistency
        let chatIds = try await [
            database.write(ChatCommands.Create(personality: defaultPersonalityId)),
            database.write(ChatCommands.Create(personality: defaultPersonalityId)),
            database.write(ChatCommands.Create(personality: defaultPersonalityId))
        ]
        
        // When & Then
        for chatId in chatIds {
            let fetchedTableName = try await database.read(ChatCommands.FetchTableName(chatId: chatId))
            let chat = try await database.read(ChatCommands.Read(chatId: chatId))
            let generatedTableName = chat.generateTableName()
            
            // Verify they match
            #expect(fetchedTableName == generatedTableName)
            
            // Verify format
            #expect(fetchedTableName.hasPrefix("t_"))
            let uuidPart = String(fetchedTableName.dropFirst(2))
            #expect(uuidPart == uuidPart.uppercased())
        }
    }
}
