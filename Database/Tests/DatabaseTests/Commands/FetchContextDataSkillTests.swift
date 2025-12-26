import Testing
import Foundation
import SwiftData
import Abstractions
import DataAssets
@testable import Database
import AbstractionsTestUtilities

@Suite("FetchContextData Skill Context Tests")
@MainActor
struct FetchContextDataSkillTests {
    // MARK: - Helper Methods

    /// Creates a test database with personalities, models, and a chat
    private func createTestDatabaseWithChat() async throws -> (Database, UUID) {
        let config = DatabaseConfiguration(
            isStoredInMemoryOnly: true,
            allowsSave: true,
            ragFactory: MockRagFactory(mockRag: MockRagging())
        )
        let database = try Database.new(configuration: config)

        // Add required models and default personality
        try await addRequiredModelsForChatCommands(database)
        let defaultPersonalityId = try await getDefaultPersonalityId(database)

        // Create a chat
        let chatId = try await database.write(ChatCommands.Create(personality: defaultPersonalityId))

        return (database, chatId)
    }

    // MARK: - Skill Context Tests

    @Test("FetchContextData includes skill context when matching skills exist")
    func fetchContextDataIncludesSkillContext() async throws {
        // Given
        let (database, chatId) = try await createTestDatabaseWithChat()

        // Create a skill associated with the browser tool
        _ = try await database.write(
            SkillCommands.Create(
                name: "Web Research",
                skillDescription: "Enhances web research capabilities",
                instructions: "When searching the web, provide sources and verify information.",
                tools: ["browser.search"]
            )
        )

        // When
        let contextConfig = try await database.read(ChatCommands.FetchContextData(chatId: chatId))

        // Then
        #expect(contextConfig.skillContext != nil)
        #expect(contextConfig.skillContext?.activeSkills.count == 1)
        #expect(contextConfig.skillContext?.activeSkills.first?.name == "Web Research")
        #expect(contextConfig.skillContext?.activeSkills.first?.instructions == "When searching the web, provide sources and verify information.")
    }

    @Test("FetchContextData returns nil skillContext when no matching skills exist")
    func fetchContextDataReturnsNilSkillContextWhenNoSkills() async throws {
        // Given
        let (database, chatId) = try await createTestDatabaseWithChat()

        // Create a skill associated with a tool that isn't enabled
        _ = try await database.write(
            SkillCommands.Create(
                name: "Custom Tool Skill",
                skillDescription: "For a non-existent tool",
                instructions: "Instructions for a custom tool.",
                tools: ["custom.tool.that.does.not.exist"]
            )
        )

        // When
        let contextConfig = try await database.read(ChatCommands.FetchContextData(chatId: chatId))

        // Then - skill should not be included because the tool isn't enabled
        #expect(contextConfig.skillContext == nil)
    }

    @Test("FetchContextData includes multiple skills for multiple tools")
    func fetchContextDataIncludesMultipleSkills() async throws {
        // Given
        let (database, chatId) = try await createTestDatabaseWithChat()

        // Create skills for different tools
        _ = try await database.write(
            SkillCommands.Create(
                name: "Weather Expert",
                skillDescription: "Weather information specialist",
                instructions: "When checking weather, always mention humidity and wind.",
                tools: ["weather"]
            )
        )

        _ = try await database.write(
            SkillCommands.Create(
                name: "Search Specialist",
                skillDescription: "Privacy-focused search expert",
                instructions: "Use DuckDuckGo for privacy-focused searches.",
                tools: ["duckduckgo_search"]
            )
        )

        // When
        let contextConfig = try await database.read(ChatCommands.FetchContextData(chatId: chatId))

        // Then
        #expect(contextConfig.skillContext != nil)
        #expect(contextConfig.skillContext?.activeSkills.count == 2)

        let skillNames = Set(contextConfig.skillContext?.activeSkills.map(\.name) ?? [])
        #expect(skillNames.contains("Weather Expert"))
        #expect(skillNames.contains("Search Specialist"))
    }

    @Test("Disabled skills are not included in context")
    func disabledSkillsNotIncluded() async throws {
        // Given
        let (database, chatId) = try await createTestDatabaseWithChat()

        // Create an enabled skill
        _ = try await database.write(
            SkillCommands.Create(
                name: "Enabled Skill",
                skillDescription: "An enabled skill",
                instructions: "This skill is enabled.",
                tools: ["browser.search"]
            )
        )

        // Create a disabled skill
        let disabledSkillId = try await database.write(
            SkillCommands.Create(
                name: "Disabled Skill",
                skillDescription: "A disabled skill",
                instructions: "This skill is disabled.",
                tools: ["browser.search"]
            )
        )

        // Disable the second skill
        try await database.write(
            SkillCommands.SetEnabled(skillId: disabledSkillId, isEnabled: false)
        )

        // When
        let contextConfig = try await database.read(ChatCommands.FetchContextData(chatId: chatId))

        // Then
        #expect(contextConfig.skillContext != nil)
        #expect(contextConfig.skillContext?.activeSkills.count == 1)
        #expect(contextConfig.skillContext?.activeSkills.first?.name == "Enabled Skill")
    }
}
