import Testing
import Foundation
import SwiftData
import Abstractions
@testable import Database
import AbstractionsTestUtilities

@Suite("Tool Policy Commands Tests")
@MainActor
struct ToolPolicyCommandsTests {
    // MARK: - Create Tests

    @Test("Create tool policy successfully")
    func createPolicySuccess() async throws {
        // Given
        let config = DatabaseConfiguration(
            isStoredInMemoryOnly: true,
            allowsSave: true,
            ragFactory: MockRagFactory(mockRag: MockRagging())
        )
        let database = try Database.new(configuration: config)
        try await waitForStatus(database, expectedStatus: .ready)

        // When
        let policyId = try await database.write(
            ToolPolicyCommands.Create(
                profile: .research,
                allowList: ["python_exec"],
                denyList: ["image_generation"]
            )
        )

        // Then
        let policy = try await database.read(ToolPolicyCommands.Read(policyId: policyId))
        #expect(policy.profile == .research)
        #expect(policy.allowList.contains("python_exec"))
        #expect(policy.denyList.contains("image_generation"))
        #expect(policy.isGlobal == false)
    }

    @Test("Create global policy")
    func createGlobalPolicy() async throws {
        // Given
        let config = DatabaseConfiguration(
            isStoredInMemoryOnly: true,
            allowsSave: true,
            ragFactory: MockRagFactory(mockRag: MockRagging())
        )
        let database = try Database.new(configuration: config)
        try await waitForStatus(database, expectedStatus: .ready)

        // When
        let policyId = try await database.write(
            ToolPolicyCommands.Create(
                profile: .full,
                isGlobal: true
            )
        )

        // Then
        let policy = try await database.read(ToolPolicyCommands.Read(policyId: policyId))
        #expect(policy.isGlobal == true)
    }

    // MARK: - Upsert Tests

    @Test("Upsert global policy creates new policy")
    func upsertGlobalCreatesNew() async throws {
        // Given
        let config = DatabaseConfiguration(
            isStoredInMemoryOnly: true,
            allowsSave: true,
            ragFactory: MockRagFactory(mockRag: MockRagging())
        )
        let database = try Database.new(configuration: config)
        try await waitForStatus(database, expectedStatus: .ready)

        // When
        let policyId = try await database.write(
            ToolPolicyCommands.UpsertGlobal(profile: .coding)
        )

        // Then
        let policy = try await database.read(ToolPolicyCommands.GetGlobal())
        #expect(policy != nil)
        #expect(policy?.id == policyId)
        #expect(policy?.profile == .coding)
    }

    @Test("Upsert global policy updates existing")
    func upsertGlobalUpdatesExisting() async throws {
        // Given
        let config = DatabaseConfiguration(
            isStoredInMemoryOnly: true,
            allowsSave: true,
            ragFactory: MockRagFactory(mockRag: MockRagging())
        )
        let database = try Database.new(configuration: config)
        try await waitForStatus(database, expectedStatus: .ready)

        _ = try await database.write(
            ToolPolicyCommands.UpsertGlobal(profile: .basic)
        )

        // When
        let policyId = try await database.write(
            ToolPolicyCommands.UpsertGlobal(profile: .full)
        )

        // Then
        let policy = try await database.read(ToolPolicyCommands.Read(policyId: policyId))
        #expect(policy.profile == .full)
    }

    // MARK: - Read Tests

    @Test("GetGlobal returns global policy")
    func getGlobalReturnsPolicy() async throws {
        // Given
        let config = DatabaseConfiguration(
            isStoredInMemoryOnly: true,
            allowsSave: true,
            ragFactory: MockRagFactory(mockRag: MockRagging())
        )
        let database = try Database.new(configuration: config)
        try await waitForStatus(database, expectedStatus: .ready)

        _ = try await database.write(
            ToolPolicyCommands.UpsertGlobal(profile: .research)
        )

        // When
        let policy = try await database.read(ToolPolicyCommands.GetGlobal())

        // Then
        #expect(policy != nil)
        #expect(policy?.isGlobal == true)
        #expect(policy?.profile == .research)
    }

    @Test("GetGlobal returns nil when no global policy exists")
    func getGlobalReturnsNilWhenNone() async throws {
        // Given
        let config = DatabaseConfiguration(
            isStoredInMemoryOnly: true,
            allowsSave: true,
            ragFactory: MockRagFactory(mockRag: MockRagging())
        )
        let database = try Database.new(configuration: config)
        try await waitForStatus(database, expectedStatus: .ready)

        // When
        let policy = try await database.read(ToolPolicyCommands.GetGlobal())

        // Then
        #expect(policy == nil)
    }

    // MARK: - Update Tests

    @Test("Update policy profile")
    func updatePolicyProfile() async throws {
        // Given
        let config = DatabaseConfiguration(
            isStoredInMemoryOnly: true,
            allowsSave: true,
            ragFactory: MockRagFactory(mockRag: MockRagging())
        )
        let database = try Database.new(configuration: config)
        try await waitForStatus(database, expectedStatus: .ready)

        let policyId = try await database.write(
            ToolPolicyCommands.Create(profile: .basic)
        )

        // When
        try await database.write(
            ToolPolicyCommands.Update(policyId: policyId, profile: .coding)
        )

        // Then
        let policy = try await database.read(ToolPolicyCommands.Read(policyId: policyId))
        #expect(policy.profile == .coding)
    }

    @Test("Add to allow list")
    func addToAllowList() async throws {
        // Given
        let config = DatabaseConfiguration(
            isStoredInMemoryOnly: true,
            allowsSave: true,
            ragFactory: MockRagFactory(mockRag: MockRagging())
        )
        let database = try Database.new(configuration: config)
        try await waitForStatus(database, expectedStatus: .ready)

        let policyId = try await database.write(
            ToolPolicyCommands.Create(profile: .basic)
        )

        // When
        try await database.write(
            ToolPolicyCommands.AddToAllowList(policyId: policyId, toolName: "python_exec")
        )

        // Then
        let policy = try await database.read(ToolPolicyCommands.Read(policyId: policyId))
        #expect(policy.allowList.contains("python_exec"))
    }

    @Test("Add to deny list removes from allow list")
    func addToDenyListRemovesFromAllowList() async throws {
        // Given
        let config = DatabaseConfiguration(
            isStoredInMemoryOnly: true,
            allowsSave: true,
            ragFactory: MockRagFactory(mockRag: MockRagging())
        )
        let database = try Database.new(configuration: config)
        try await waitForStatus(database, expectedStatus: .ready)

        let policyId = try await database.write(
            ToolPolicyCommands.Create(
                profile: .basic,
                allowList: ["python_exec"]
            )
        )

        // When
        try await database.write(
            ToolPolicyCommands.AddToDenyList(policyId: policyId, toolName: "python_exec")
        )

        // Then
        let policy = try await database.read(ToolPolicyCommands.Read(policyId: policyId))
        #expect(!policy.allowList.contains("python_exec"))
        #expect(policy.denyList.contains("python_exec"))
    }

    // MARK: - Delete Tests

    @Test("Delete policy removes it")
    func deletePolicyRemovesIt() async throws {
        // Given
        let config = DatabaseConfiguration(
            isStoredInMemoryOnly: true,
            allowsSave: true,
            ragFactory: MockRagFactory(mockRag: MockRagging())
        )
        let database = try Database.new(configuration: config)
        try await waitForStatus(database, expectedStatus: .ready)

        let policyId = try await database.write(
            ToolPolicyCommands.Create(profile: .basic)
        )

        // When
        try await database.write(ToolPolicyCommands.Delete(policyId: policyId))

        // Then
        await #expect(throws: DatabaseError.toolPolicyNotFound) {
            _ = try await database.read(ToolPolicyCommands.Read(policyId: policyId))
        }
    }

    // MARK: - Tool Profile Tests

    @Test("Tool profiles contain expected tools")
    func toolProfilesContainExpectedTools() {
        // Minimal profile
        #expect(ToolProfile.minimal.includedTools.isEmpty)

        // Basic profile
        #expect(ToolProfile.basic.includedTools.contains(.browser))
        #expect(!ToolProfile.basic.includedTools.contains(.python))

        // Research profile
        #expect(ToolProfile.research.includedTools.contains(.browser))
        #expect(ToolProfile.research.includedTools.contains(.duckduckgo))
        #expect(ToolProfile.research.includedTools.contains(.memory))

        // Coding profile
        #expect(ToolProfile.coding.includedTools.contains(.python))
        #expect(ToolProfile.coding.includedTools.contains(.browser))

        // Full profile
        #expect(ToolProfile.full.includedTools.count == ToolIdentifier.allCases.count)
    }

    // MARK: - Resolved Policy Tests

    @Test("Resolved policy filters tools correctly")
    func resolvedPolicyFiltersTools() {
        // Given
        let resolved = ResolvedToolPolicy(
            allowedTools: [.browser, .python],
            sourceProfile: .coding
        )

        // Then
        #expect(resolved.isToolAllowed(.browser))
        #expect(resolved.isToolAllowed(.python))
        #expect(!resolved.isToolAllowed(.duckduckgo))

        // Filter test
        let requested: Set<ToolIdentifier> = [.browser, .duckduckgo, .python, .memory]
        let filtered = resolved.filterAllowed(requested)
        #expect(filtered == [.browser, .python])
    }

    @Test("ResolveForChat returns full access when no policies exist")
    func resolveForChatReturnsFullAccessWhenNoPolicies() async throws {
        // Given
        let config = DatabaseConfiguration(
            isStoredInMemoryOnly: true,
            allowsSave: true,
            ragFactory: MockRagFactory(mockRag: MockRagging())
        )
        let database = try Database.new(configuration: config)
        try await waitForStatus(database, expectedStatus: .ready)

        // When
        let resolved = try await database.read(
            ToolPolicyCommands.ResolveForChat(chatId: UUID())
        )

        // Then
        #expect(resolved.allowedTools == Set(ToolIdentifier.allCases))
        #expect(resolved.sourceProfile == .full)
    }

    // MARK: - Policy Resolution Hierarchy Tests

    @Test("ResolveForChat uses chat-specific policy over global policy")
    func resolveForChatUsesChatPolicyOverGlobal() async throws {
        // Given
        let config = DatabaseConfiguration(
            isStoredInMemoryOnly: true,
            allowsSave: true,
            ragFactory: MockRagFactory(mockRag: MockRagging())
        )
        let database = try Database.new(configuration: config)
        try await waitForStatus(database, expectedStatus: .ready)
        try await addRequiredModelsForChatCommands(database)

        // Create a chat
        let personalityId = try await getDefaultPersonalityId(database)
        let chatId = try await database.write(ChatCommands.Create(personality: personalityId))

        // Create global policy with full access
        _ = try await database.write(
            ToolPolicyCommands.UpsertGlobal(profile: .full)
        )

        // Create chat-specific policy with minimal access
        _ = try await database.write(
            ToolPolicyCommands.UpsertForChat(chatId: chatId, profile: .minimal)
        )

        // When
        let resolved = try await database.read(
            ToolPolicyCommands.ResolveForChat(chatId: chatId)
        )

        // Then - Chat policy should win
        #expect(resolved.sourceProfile == .minimal)
        #expect(resolved.allowedTools.isEmpty)
    }

    @Test("ResolveForChat uses global policy when no chat policy exists")
    func resolveForChatUsesGlobalPolicyWhenNoChatPolicy() async throws {
        // Given
        let config = DatabaseConfiguration(
            isStoredInMemoryOnly: true,
            allowsSave: true,
            ragFactory: MockRagFactory(mockRag: MockRagging())
        )
        let database = try Database.new(configuration: config)
        try await waitForStatus(database, expectedStatus: .ready)
        try await addRequiredModelsForChatCommands(database)

        // Create a chat
        let personalityId = try await getDefaultPersonalityId(database)
        let chatId = try await database.write(ChatCommands.Create(personality: personalityId))

        // Create only global policy with coding profile
        _ = try await database.write(
            ToolPolicyCommands.UpsertGlobal(profile: .coding)
        )

        // When
        let resolved = try await database.read(
            ToolPolicyCommands.ResolveForChat(chatId: chatId)
        )

        // Then - Global policy should be used
        #expect(resolved.sourceProfile == .coding)
        #expect(resolved.allowedTools.contains(.python))
        #expect(resolved.allowedTools.contains(.browser))
    }

    @Test("ResolveForChat applies allow list additions")
    func resolveForChatAppliesAllowList() async throws {
        // Given
        let config = DatabaseConfiguration(
            isStoredInMemoryOnly: true,
            allowsSave: true,
            ragFactory: MockRagFactory(mockRag: MockRagging())
        )
        let database = try Database.new(configuration: config)
        try await waitForStatus(database, expectedStatus: .ready)
        try await addRequiredModelsForChatCommands(database)

        // Create a chat
        let personalityId = try await getDefaultPersonalityId(database)
        let chatId = try await database.write(ChatCommands.Create(personality: personalityId))

        // Create policy with basic profile + python in allow list
        _ = try await database.write(
            ToolPolicyCommands.UpsertForChat(
                chatId: chatId,
                profile: .basic,
                allowList: ["python_exec"]
            )
        )

        // When
        let resolved = try await database.read(
            ToolPolicyCommands.ResolveForChat(chatId: chatId)
        )

        // Then - Should include basic tools + python from allow list
        #expect(resolved.sourceProfile == .basic)
        #expect(resolved.allowedTools.contains(.browser))
        #expect(resolved.allowedTools.contains(.python))
        #expect(resolved.addedTools.contains(.python))
    }

    @Test("ResolveForChat applies deny list removals")
    func resolveForChatAppliesDenyList() async throws {
        // Given
        let config = DatabaseConfiguration(
            isStoredInMemoryOnly: true,
            allowsSave: true,
            ragFactory: MockRagFactory(mockRag: MockRagging())
        )
        let database = try Database.new(configuration: config)
        try await waitForStatus(database, expectedStatus: .ready)
        try await addRequiredModelsForChatCommands(database)

        // Create a chat
        let personalityId = try await getDefaultPersonalityId(database)
        let chatId = try await database.write(ChatCommands.Create(personality: personalityId))

        // Create policy with research profile but deny browser
        _ = try await database.write(
            ToolPolicyCommands.UpsertForChat(
                chatId: chatId,
                profile: .research,
                denyList: ["browser.search"]
            )
        )

        // When
        let resolved = try await database.read(
            ToolPolicyCommands.ResolveForChat(chatId: chatId)
        )

        // Then - Browser should be removed even though it's in research profile
        #expect(resolved.sourceProfile == .research)
        #expect(!resolved.allowedTools.contains(.browser))
        #expect(resolved.removedTools.contains(.browser))
        #expect(resolved.allowedTools.contains(.duckduckgo))
    }

    @Test("ResolveForChat uses personality policy when no chat policy exists")
    func resolveForChatUsesPersonalityPolicy() async throws {
        // Given
        let config = DatabaseConfiguration(
            isStoredInMemoryOnly: true,
            allowsSave: true,
            ragFactory: MockRagFactory(mockRag: MockRagging())
        )
        let database = try Database.new(configuration: config)
        try await waitForStatus(database, expectedStatus: .ready)
        try await addRequiredModelsForChatCommands(database)

        // Create a chat
        let personalityId = try await getDefaultPersonalityId(database)
        let chatId = try await database.write(ChatCommands.Create(personality: personalityId))

        // Create personality-specific policy
        _ = try await database.write(
            ToolPolicyCommands.Create(
                profile: .research,
                personalityId: personalityId
            )
        )

        // Create global policy with different profile
        _ = try await database.write(
            ToolPolicyCommands.UpsertGlobal(profile: .full)
        )

        // When
        let resolved = try await database.read(
            ToolPolicyCommands.ResolveForChat(chatId: chatId)
        )

        // Then - Personality policy should win over global
        #expect(resolved.sourceProfile == .research)
    }

    @Test("Chat policy takes priority over personality policy")
    func chatPolicyOverPersonalityPolicy() async throws {
        // Given
        let config = DatabaseConfiguration(
            isStoredInMemoryOnly: true,
            allowsSave: true,
            ragFactory: MockRagFactory(mockRag: MockRagging())
        )
        let database = try Database.new(configuration: config)
        try await waitForStatus(database, expectedStatus: .ready)
        try await addRequiredModelsForChatCommands(database)

        // Create a chat
        let personalityId = try await getDefaultPersonalityId(database)
        let chatId = try await database.write(ChatCommands.Create(personality: personalityId))

        // Create personality-specific policy
        _ = try await database.write(
            ToolPolicyCommands.Create(
                profile: .research,
                personalityId: personalityId
            )
        )

        // Create chat-specific policy with different profile
        _ = try await database.write(
            ToolPolicyCommands.UpsertForChat(chatId: chatId, profile: .minimal)
        )

        // When
        let resolved = try await database.read(
            ToolPolicyCommands.ResolveForChat(chatId: chatId)
        )

        // Then - Chat policy should win
        #expect(resolved.sourceProfile == .minimal)
    }

    @Test("GetForChat returns chat-specific policy")
    func getForChatReturnsChatPolicy() async throws {
        // Given
        let config = DatabaseConfiguration(
            isStoredInMemoryOnly: true,
            allowsSave: true,
            ragFactory: MockRagFactory(mockRag: MockRagging())
        )
        let database = try Database.new(configuration: config)
        try await waitForStatus(database, expectedStatus: .ready)
        try await addRequiredModelsForChatCommands(database)

        // Create a chat
        let personalityId = try await getDefaultPersonalityId(database)
        let chatId = try await database.write(ChatCommands.Create(personality: personalityId))

        // Create chat-specific policy
        let policyId = try await database.write(
            ToolPolicyCommands.UpsertForChat(chatId: chatId, profile: .coding)
        )

        // When
        let policy = try await database.read(
            ToolPolicyCommands.GetForChat(chatId: chatId)
        )

        // Then
        #expect(policy != nil)
        #expect(policy?.id == policyId)
        #expect(policy?.profile == .coding)
    }

    @Test("GetForChat returns nil when no chat policy exists")
    func getForChatReturnsNilWhenNone() async throws {
        // Given
        let config = DatabaseConfiguration(
            isStoredInMemoryOnly: true,
            allowsSave: true,
            ragFactory: MockRagFactory(mockRag: MockRagging())
        )
        let database = try Database.new(configuration: config)
        try await waitForStatus(database, expectedStatus: .ready)
        try await addRequiredModelsForChatCommands(database)

        // Create a chat without policy
        let personalityId = try await getDefaultPersonalityId(database)
        let chatId = try await database.write(ChatCommands.Create(personality: personalityId))

        // When
        let policy = try await database.read(
            ToolPolicyCommands.GetForChat(chatId: chatId)
        )

        // Then
        #expect(policy == nil)
    }

    @Test("DeleteForChat removes chat-specific policy")
    func deleteForChatRemovesPolicy() async throws {
        // Given
        let config = DatabaseConfiguration(
            isStoredInMemoryOnly: true,
            allowsSave: true,
            ragFactory: MockRagFactory(mockRag: MockRagging())
        )
        let database = try Database.new(configuration: config)
        try await waitForStatus(database, expectedStatus: .ready)
        try await addRequiredModelsForChatCommands(database)

        // Create a chat with policy
        let personalityId = try await getDefaultPersonalityId(database)
        let chatId = try await database.write(ChatCommands.Create(personality: personalityId))
        _ = try await database.write(
            ToolPolicyCommands.UpsertForChat(chatId: chatId, profile: .coding)
        )

        // When
        _ = try await database.write(
            ToolPolicyCommands.DeleteForChat(chatId: chatId)
        )

        // Then
        let policy = try await database.read(
            ToolPolicyCommands.GetForChat(chatId: chatId)
        )
        #expect(policy == nil)
    }

    // MARK: - Personality Policy Tests

    @Test("UpsertForPersonality creates new policy")
    func upsertForPersonalityCreatesNew() async throws {
        // Given
        let config = DatabaseConfiguration(
            isStoredInMemoryOnly: true,
            allowsSave: true,
            ragFactory: MockRagFactory(mockRag: MockRagging())
        )
        let database = try Database.new(configuration: config)
        try await waitForStatus(database, expectedStatus: .ready)
        try await addRequiredModelsForChatCommands(database)

        let personalityId = try await getDefaultPersonalityId(database)

        // When
        let policyId = try await database.write(
            ToolPolicyCommands.UpsertForPersonality(
                personalityId: personalityId,
                profile: .research,
                allowList: ["python_exec"]
            )
        )

        // Then
        let policy = try await database.read(
            ToolPolicyCommands.GetForPersonality(personalityId: personalityId)
        )
        #expect(policy != nil)
        #expect(policy?.id == policyId)
        #expect(policy?.profile == .research)
        #expect(policy?.allowList.contains("python_exec") == true)
    }

    @Test("UpsertForPersonality updates existing policy")
    func upsertForPersonalityUpdatesExisting() async throws {
        // Given
        let config = DatabaseConfiguration(
            isStoredInMemoryOnly: true,
            allowsSave: true,
            ragFactory: MockRagFactory(mockRag: MockRagging())
        )
        let database = try Database.new(configuration: config)
        try await waitForStatus(database, expectedStatus: .ready)
        try await addRequiredModelsForChatCommands(database)

        let personalityId = try await getDefaultPersonalityId(database)

        // Create initial policy
        let policyId = try await database.write(
            ToolPolicyCommands.UpsertForPersonality(
                personalityId: personalityId,
                profile: .basic
            )
        )

        // When - Update with different profile
        let updatedPolicyId = try await database.write(
            ToolPolicyCommands.UpsertForPersonality(
                personalityId: personalityId,
                profile: .coding,
                denyList: ["browser.search"]
            )
        )

        // Then
        #expect(policyId == updatedPolicyId)
        let policy = try await database.read(
            ToolPolicyCommands.GetForPersonality(personalityId: personalityId)
        )
        #expect(policy?.profile == .coding)
        #expect(policy?.denyList.contains("browser.search") == true)
    }

    @Test("GetForPersonality returns nil when no personality policy exists")
    func getForPersonalityReturnsNilWhenNone() async throws {
        // Given
        let config = DatabaseConfiguration(
            isStoredInMemoryOnly: true,
            allowsSave: true,
            ragFactory: MockRagFactory(mockRag: MockRagging())
        )
        let database = try Database.new(configuration: config)
        try await waitForStatus(database, expectedStatus: .ready)
        try await addRequiredModelsForChatCommands(database)

        let personalityId = try await getDefaultPersonalityId(database)

        // When
        let policy = try await database.read(
            ToolPolicyCommands.GetForPersonality(personalityId: personalityId)
        )

        // Then
        #expect(policy == nil)
    }

    @Test("Personality policy doesn't affect other personalities")
    func personalityPolicyIsolated() async throws {
        // Given
        let config = DatabaseConfiguration(
            isStoredInMemoryOnly: true,
            allowsSave: true,
            ragFactory: MockRagFactory(mockRag: MockRagging())
        )
        let database = try Database.new(configuration: config)
        try await waitForStatus(database, expectedStatus: .ready)
        try await addRequiredModelsForChatCommands(database)

        let personality1Id = try await getDefaultPersonalityId(database)

        // Create a custom personality
        let personality2Id = try await database.write(
            PersonalityCommands.CreateCustom(
                name: "Test Personality",
                description: "A test personality",
                customSystemInstruction: "You are a test assistant.",
                category: .productivity
            )
        )

        // Create policy for personality1
        _ = try await database.write(
            ToolPolicyCommands.UpsertForPersonality(
                personalityId: personality1Id,
                profile: .minimal
            )
        )

        // When - Check personality2's policy
        let policy = try await database.read(
            ToolPolicyCommands.GetForPersonality(personalityId: personality2Id)
        )

        // Then - Personality2 should have no policy
        #expect(policy == nil)
    }
}

// MARK: - Helper Functions

private func waitForStatus(_ database: Database, expectedStatus: DatabaseStatus) async throws {
    let timeout: UInt64 = 5_000_000_000 // 5 seconds in nanoseconds
    let interval: UInt64 = 100_000_000 // 100ms check interval
    var elapsed: UInt64 = 0

    while elapsed < timeout {
        let currentStatus = await database.status
        if currentStatus == expectedStatus {
            return
        }
        try await Task.sleep(nanoseconds: interval)
        elapsed += interval
    }

    throw DatabaseError.timeout
}
