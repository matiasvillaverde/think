import Testing
import Foundation
import SwiftData
import Abstractions
import DataAssets
@testable import Database
import AbstractionsTestUtilities

@Suite("Chat Commands Basic Functionality Tests", .tags(.acceptance))
struct ChatCommandsBasicTests {
    @Test("Create chat successfully with valid models")
    func createChatSuccess() async throws {
        // Given
        let config = DatabaseConfiguration(
            isStoredInMemoryOnly: true,
            allowsSave: true,
            ragFactory: MockRagFactory(mockRag: MockRagging())
        )

        let database = try Database.new(configuration: config)
        try await addRequiredModelsForChatCommands(database)
        let defaultPersonalityId = try await getDefaultPersonalityId(database)

        // When
        try await database.write(ChatCommands.Create(personality: defaultPersonalityId))

        // Then
        let chatCount = try await database.read(ValidateChatCountCommand())
        #expect(chatCount == 1)
    }

    @MainActor
    @Test("Create chat successfully with system instruction")
    func createChatSystemInstruction() async throws {
        // Given
        let config = DatabaseConfiguration(
            isStoredInMemoryOnly: true,
            allowsSave: true,
            ragFactory: MockRagFactory(mockRag: MockRagging())
        )

        let database = try Database.new(configuration: config)
        try await addRequiredModelsForChatCommands(database)
        let defaultPersonalityId = try await getDefaultPersonalityId(database)

        // When
        let id = try await database.write(ChatCommands.Create(personality: defaultPersonalityId))

        // Then
        let chat = try await database.read(ChatCommands.Read(chatId: id))
        #expect(chat.languageModelConfig.systemInstruction == SystemInstruction.englishAssistant)
    }

    @Test("Create chat reuses models from most recent chat")
    @MainActor
    func createChatReusesModels() async throws {
        // Given
        let config = DatabaseConfiguration(
            isStoredInMemoryOnly: true,
            allowsSave: true,
            ragFactory: MockRagFactory(mockRag: MockRagging())
        )

        let database = try Database.new(configuration: config)
        try await addRequiredModelsForChatCommands(database)
        let defaultPersonalityId = try await getDefaultPersonalityId(database)

        // Create a first chat
        let firstChatId = try await database.write(ChatCommands.Create(personality: defaultPersonalityId))

        // When - Create a second chat
        let secondChatId = try await database.write(ChatCommands.Create(personality: defaultPersonalityId))

        // Then - Check that both chats use the same models
        let haveSameModels = try await database.read(
            ChatCommands.HaveSameModels(chatId1: firstChatId, chatId2: secondChatId)
        )

        #expect(haveSameModels == true, "The second chat should reuse models from the first chat")

        // Additional verification
        let firstChat = try await database.read(ChatCommands.Read(chatId: firstChatId))
        let secondChat = try await database.read(ChatCommands.Read(chatId: secondChatId))

        #expect(firstChat.languageModel.id == secondChat.languageModel.id)
        #expect(firstChat.imageModel.id == secondChat.imageModel.id)
    }

    @Test("Read chat successfully with valid models")
    @MainActor
    func readChatSuccessfully() async throws {
        // Given
        let config = DatabaseConfiguration(
            isStoredInMemoryOnly: true,
            allowsSave: true,
            ragFactory: MockRagFactory(mockRag: MockRagging())
        )

        let database = try Database.new(configuration: config)
        try await addRequiredModelsForChatCommands(database)
        let defaultPersonalityId = try await getDefaultPersonalityId(database)

        // When
        let id = try await database.write(ChatCommands.Create(personality: defaultPersonalityId))

        // Then
        let chat = try await database.read(ChatCommands.Read(chatId: id))
        #expect(chat.id == id)
    }

    @Test("Delete chat successfully")
    @MainActor
    func deleteChatSuccess() async throws {
        // Given
        let config = DatabaseConfiguration(
            isStoredInMemoryOnly: true,
            allowsSave: true,
            ragFactory: MockRagFactory(mockRag: MockRagging())
        )

        let database = try Database.new(configuration: config)
        try await addRequiredModelsForChatCommands(database)
        let defaultPersonalityId = try await getDefaultPersonalityId(database)
        try await database.write(ChatCommands.Create(personality: defaultPersonalityId))

        // Get the chat ID
        let chat = try await database.read(ChatCommands.GetFirst())

        let chatCount = try await database.read(ValidateChatCountCommand())
        #expect(chatCount == 1)

        // When
        try await database.write(ChatCommands.Delete(id: chat.id))

        // Then
        let chatCountAfterDelete = try await database.read(ValidateChatCountCommand())
        #expect(chatCountAfterDelete == 0) // The setup of the DB creates one Chat
    }
}
