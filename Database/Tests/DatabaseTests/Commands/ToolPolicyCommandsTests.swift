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
