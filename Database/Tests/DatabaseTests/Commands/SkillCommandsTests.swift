import Testing
import Foundation
import SwiftData
import Abstractions
@testable import Database
import AbstractionsTestUtilities

@Suite("Skill Commands Tests")
@MainActor
struct SkillCommandsTests {
    // MARK: - Create Tests

    @Test("Create skill successfully")
    func createSkillSuccess() async throws {
        // Given
        let config = DatabaseConfiguration(
            isStoredInMemoryOnly: true,
            allowsSave: true,
            ragFactory: MockRagFactory(mockRag: MockRagging())
        )
        let database = try Database.new(configuration: config)
        try await waitForStatus(database, expectedStatus: .ready)

        // When
        let skillId = try await database.write(
            SkillCommands.Create(
                name: "Web Research",
                skillDescription: "Research topics using web tools",
                instructions: "Use duckduckgo_search first, then browser",
                tools: ["duckduckgo_search", "browser.search"]
            )
        )

        // Then
        let skill = try await database.read(SkillCommands.Read(skillId: skillId))
        #expect(skill.name == "Web Research")
        #expect(skill.skillDescription == "Research topics using web tools")
        #expect(skill.instructions == "Use duckduckgo_search first, then browser")
        #expect(skill.tools.contains("duckduckgo_search"))
        #expect(skill.tools.contains("browser.search"))
        #expect(skill.isEnabled == true)
        #expect(skill.isSystem == false)
    }

    @Test("Create system skill")
    func createSystemSkill() async throws {
        // Given
        let config = DatabaseConfiguration(
            isStoredInMemoryOnly: true,
            allowsSave: true,
            ragFactory: MockRagFactory(mockRag: MockRagging())
        )
        let database = try Database.new(configuration: config)
        try await waitForStatus(database, expectedStatus: .ready)

        // When
        let skillId = try await database.write(
            SkillCommands.Create(
                name: "Bundled Skill",
                skillDescription: "A system skill",
                instructions: "Do things",
                isSystem: true
            )
        )

        // Then
        let skill = try await database.read(SkillCommands.Read(skillId: skillId))
        #expect(skill.isSystem == true)
    }

    // MARK: - Upsert Tests

    @Test("Upsert skill creates new skill")
    func upsertSkillCreatesNew() async throws {
        // Given
        let config = DatabaseConfiguration(
            isStoredInMemoryOnly: true,
            allowsSave: true,
            ragFactory: MockRagFactory(mockRag: MockRagging())
        )
        let database = try Database.new(configuration: config)
        try await waitForStatus(database, expectedStatus: .ready)

        // When
        let skillId = try await database.write(
            SkillCommands.Upsert(
                name: "Code Review",
                skillDescription: "Review code systematically",
                instructions: "Check for bugs, style, performance"
            )
        )

        // Then
        let skill = try await database.read(SkillCommands.Read(skillId: skillId))
        #expect(skill.name == "Code Review")
        #expect(skill.isSystem == true)
    }

    @Test("Upsert skill updates existing skill")
    func upsertSkillUpdatesExisting() async throws {
        // Given
        let config = DatabaseConfiguration(
            isStoredInMemoryOnly: true,
            allowsSave: true,
            ragFactory: MockRagFactory(mockRag: MockRagging())
        )
        let database = try Database.new(configuration: config)
        try await waitForStatus(database, expectedStatus: .ready)

        _ = try await database.write(
            SkillCommands.Upsert(
                name: "Code Review",
                skillDescription: "Original description",
                instructions: "Original instructions"
            )
        )

        // When
        let skillId = try await database.write(
            SkillCommands.Upsert(
                name: "Code Review",
                skillDescription: "Updated description",
                instructions: "Updated instructions"
            )
        )

        // Then
        let skill = try await database.read(SkillCommands.Read(skillId: skillId))
        #expect(skill.skillDescription == "Updated description")
        #expect(skill.instructions == "Updated instructions")
    }

    // MARK: - Read Tests

    @Test("GetAll returns all user skills")
    func getAllReturnsAllSkills() async throws {
        // Given
        let config = DatabaseConfiguration(
            isStoredInMemoryOnly: true,
            allowsSave: true,
            ragFactory: MockRagFactory(mockRag: MockRagging())
        )
        let database = try Database.new(configuration: config)
        try await waitForStatus(database, expectedStatus: .ready)

        _ = try await database.write(
            SkillCommands.Create(
                name: "Skill 1",
                skillDescription: "First skill",
                instructions: "Instructions 1"
            )
        )
        _ = try await database.write(
            SkillCommands.Create(
                name: "Skill 2",
                skillDescription: "Second skill",
                instructions: "Instructions 2"
            )
        )

        // When
        let skills = try await database.read(SkillCommands.GetAll())

        // Then
        #expect(skills.count == 2)
    }

    @Test("GetForTools returns skills matching tools")
    func getForToolsReturnsMatchingSkills() async throws {
        // Given
        let config = DatabaseConfiguration(
            isStoredInMemoryOnly: true,
            allowsSave: true,
            ragFactory: MockRagFactory(mockRag: MockRagging())
        )
        let database = try Database.new(configuration: config)
        try await waitForStatus(database, expectedStatus: .ready)

        _ = try await database.write(
            SkillCommands.Create(
                name: "Web Skill",
                skillDescription: "Web research",
                instructions: "Search the web",
                tools: ["duckduckgo_search", "browser.search"]
            )
        )
        _ = try await database.write(
            SkillCommands.Create(
                name: "Python Skill",
                skillDescription: "Python coding",
                instructions: "Use Python",
                tools: ["python_exec"]
            )
        )

        // When
        let webSkills = try await database.read(
            SkillCommands.GetForTools(toolIdentifiers: Set(["duckduckgo_search"]))
        )

        // Then
        #expect(webSkills.count == 1)
        #expect(webSkills.first?.name == "Web Skill")
    }

    @Test("GetSkillContext returns skill context for tools")
    func getSkillContextReturnsContext() async throws {
        // Given
        let config = DatabaseConfiguration(
            isStoredInMemoryOnly: true,
            allowsSave: true,
            ragFactory: MockRagFactory(mockRag: MockRagging())
        )
        let database = try Database.new(configuration: config)
        try await waitForStatus(database, expectedStatus: .ready)

        _ = try await database.write(
            SkillCommands.Create(
                name: "Research Skill",
                skillDescription: "Research effectively",
                instructions: "Cross-reference sources",
                tools: ["browser.search"]
            )
        )

        // When
        let context = try await database.read(
            SkillCommands.GetSkillContext(toolIdentifiers: Set(["browser.search"]))
        )

        // Then
        #expect(!context.isEmpty)
        #expect(context.activeSkills.count == 1)
        #expect(context.activeSkills.first?.name == "Research Skill")
    }

    // MARK: - Update Tests

    @Test("Update skill content")
    func updateSkillContent() async throws {
        // Given
        let config = DatabaseConfiguration(
            isStoredInMemoryOnly: true,
            allowsSave: true,
            ragFactory: MockRagFactory(mockRag: MockRagging())
        )
        let database = try Database.new(configuration: config)
        try await waitForStatus(database, expectedStatus: .ready)

        let skillId = try await database.write(
            SkillCommands.Create(
                name: "Original Name",
                skillDescription: "Original description",
                instructions: "Original instructions"
            )
        )

        // When
        try await database.write(
            SkillCommands.Update(
                skillId: skillId,
                name: "Updated Name",
                skillDescription: "Updated description"
            )
        )

        // Then
        let skill = try await database.read(SkillCommands.Read(skillId: skillId))
        #expect(skill.name == "Updated Name")
        #expect(skill.skillDescription == "Updated description")
        #expect(skill.instructions == "Original instructions")
    }

    @Test("SetEnabled toggles skill state")
    func setEnabledTogglesState() async throws {
        // Given
        let config = DatabaseConfiguration(
            isStoredInMemoryOnly: true,
            allowsSave: true,
            ragFactory: MockRagFactory(mockRag: MockRagging())
        )
        let database = try Database.new(configuration: config)
        try await waitForStatus(database, expectedStatus: .ready)

        let skillId = try await database.write(
            SkillCommands.Create(
                name: "Toggle Skill",
                skillDescription: "A skill to toggle",
                instructions: "Instructions"
            )
        )

        // When
        try await database.write(SkillCommands.SetEnabled(skillId: skillId, isEnabled: false))

        // Then
        let skill = try await database.read(SkillCommands.Read(skillId: skillId))
        #expect(skill.isEnabled == false)
    }

    // MARK: - Delete Tests

    @Test("Delete skill removes it")
    func deleteSkillRemovesIt() async throws {
        // Given
        let config = DatabaseConfiguration(
            isStoredInMemoryOnly: true,
            allowsSave: true,
            ragFactory: MockRagFactory(mockRag: MockRagging())
        )
        let database = try Database.new(configuration: config)
        try await waitForStatus(database, expectedStatus: .ready)

        let skillId = try await database.write(
            SkillCommands.Create(
                name: "To Delete",
                skillDescription: "Will be deleted",
                instructions: "Instructions"
            )
        )

        // When
        try await database.write(SkillCommands.Delete(skillId: skillId))

        // Then
        await #expect(throws: DatabaseError.skillNotFound) {
            _ = try await database.read(SkillCommands.Read(skillId: skillId))
        }
    }

    @Test("Disabled skills are excluded from GetForTools")
    func disabledSkillsExcludedFromGetForTools() async throws {
        // Given
        let config = DatabaseConfiguration(
            isStoredInMemoryOnly: true,
            allowsSave: true,
            ragFactory: MockRagFactory(mockRag: MockRagging())
        )
        let database = try Database.new(configuration: config)
        try await waitForStatus(database, expectedStatus: .ready)

        let skillId = try await database.write(
            SkillCommands.Create(
                name: "Disabled Skill",
                skillDescription: "Will be disabled",
                instructions: "Instructions",
                tools: ["browser.search"]
            )
        )
        try await database.write(SkillCommands.SetEnabled(skillId: skillId, isEnabled: false))

        // When
        let skills = try await database.read(
            SkillCommands.GetForTools(toolIdentifiers: Set(["browser.search"]))
        )

        // Then
        #expect(skills.isEmpty)
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
