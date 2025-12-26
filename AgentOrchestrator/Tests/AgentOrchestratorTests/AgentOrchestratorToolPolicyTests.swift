import Abstractions
import AbstractionsTestUtilities
@testable import AgentOrchestrator
import ContextBuilder
@testable import Database
import Foundation
import Testing
import Tools

@Suite("AgentOrchestrator Tool Policy Tests")
internal struct AgentOrchestratorToolPolicyTests {
    // MARK: - ContextConfiguration allowedTools Tests

    @Test("ContextConfiguration stores allowed tools")
    internal func contextConfigurationStoresAllowedTools() {
        // Given
        let allowedTools: Set<ToolIdentifier> = [.browser, .duckduckgo]

        // When
        let config: ContextConfiguration = ContextConfiguration(
            systemInstruction: "Test",
            contextMessages: [],
            maxPrompt: 1_000,
            allowedTools: allowedTools,
            hasToolPolicy: true
        )

        // Then
        #expect(config.allowedTools == allowedTools)
        #expect(config.hasToolPolicy == true)
    }

    @Test("ContextConfiguration defaults to all tools when no policy")
    internal func contextConfigurationDefaultsToAllTools() {
        // When
        let config: ContextConfiguration = ContextConfiguration(
            systemInstruction: "Test",
            contextMessages: [],
            maxPrompt: 1_000
        )

        // Then - defaults to all tools and hasToolPolicy = false
        #expect(config.allowedTools == Set(ToolIdentifier.allCases))
        #expect(config.hasToolPolicy == false)
    }

    // MARK: - FetchContextData Tool Policy Tests

    @Test("FetchContextData includes allowed tools from resolved policy")
    @MainActor
    internal func fetchContextDataIncludesAllowedTools() async throws {
        // Given
        let database: Database = try await AgentOrchestratorTestHelpers.createTestDatabase()
        let chatId: UUID = try await AgentOrchestratorTestHelpers.setupChatWithModel(database)

        // When
        let contextConfig: ContextConfiguration = try await database.read(
            ChatCommands.FetchContextData(chatId: chatId)
        )

        // Then - should have allowed tools and hasToolPolicy should be true
        // When no specific policy is set, ResolveForChat returns allowAll which has all tools
        #expect(contextConfig.hasToolPolicy == true)
        #expect(!contextConfig.allowedTools.isEmpty)
    }

    @Test("FetchContextData uses personality tool policy when set")
    @MainActor
    internal func fetchContextDataUsesPersonalityPolicy() async throws {
        // Given
        let database: Database = try await AgentOrchestratorTestHelpers.createTestDatabase()
        let chatId: UUID = try await AgentOrchestratorTestHelpers.setupChatWithModel(database)

        // Get the personality ID from the chat
        let chat: Chat = try await database.read(ChatCommands.Read(chatId: chatId))
        let personalityId: UUID = chat.personality.id

        // Create a restrictive policy for the personality (basic profile = browser only)
        _ = try await database.write(
            ToolPolicyCommands.UpsertForPersonality(
                personalityId: personalityId,
                profile: .basic,
                allowList: [],
                denyList: []
            )
        )

        // When
        let contextConfig: ContextConfiguration = try await database.read(
            ChatCommands.FetchContextData(chatId: chatId)
        )

        // Then - allowed tools should be filtered by personality policy
        #expect(contextConfig.hasToolPolicy == true)
        // Basic profile only includes browser
        #expect(contextConfig.allowedTools == ToolProfile.basic.includedTools)
    }

    @Test("FetchContextData respects minimal profile with no tools")
    @MainActor
    internal func fetchContextDataRespectsMinimalProfile() async throws {
        // Given
        let database: Database = try await AgentOrchestratorTestHelpers.createTestDatabase()
        let chatId: UUID = try await AgentOrchestratorTestHelpers.setupChatWithModel(database)

        // Get the personality ID from the chat
        let chat: Chat = try await database.read(ChatCommands.Read(chatId: chatId))
        let personalityId: UUID = chat.personality.id

        // Create a minimal policy (no tools)
        _ = try await database.write(
            ToolPolicyCommands.UpsertForPersonality(
                personalityId: personalityId,
                profile: .minimal,
                allowList: [],
                denyList: []
            )
        )

        // When
        let contextConfig: ContextConfiguration = try await database.read(
            ChatCommands.FetchContextData(chatId: chatId)
        )

        // Then - allowed tools should be empty (minimal profile)
        #expect(contextConfig.hasToolPolicy == true)
        #expect(contextConfig.allowedTools.isEmpty)
    }
}
