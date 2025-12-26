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

    // MARK: - Skill Auto-Activation Tests

    @Test("Skills should activate when matching tools are configured")
    func skillsActivateWithMatchingTools() async throws {
        // Given - A skill associated with "duckduckgo_search" tool
        let config = DatabaseConfiguration(
            isStoredInMemoryOnly: true,
            allowsSave: true,
            ragFactory: MockRagFactory(mockRag: MockRagging())
        )
        let database = try Database.new(configuration: config)
        try await waitForStatus(database, expectedStatus: .ready)

        _ = try await database.write(
            SkillCommands.Create(
                name: "Web Research",
                skillDescription: "Research topics using search engines",
                instructions: "Use duckduckgo_search first for general queries, then browser for specific pages",
                tools: ["duckduckgo_search", "browser.search"]
            )
        )

        // When - Query with one of the associated tools
        let skills = try await database.read(
            SkillCommands.GetForTools(toolIdentifiers: Set(["duckduckgo_search"]))
        )

        // Then - Skill should be found
        #expect(skills.count == 1)
        #expect(skills.first?.name == "Web Research")
    }

    @Test("GetSkillContext includes all skills for multiple tools")
    func getSkillContextIncludesMultipleSkills() async throws {
        // Given - Multiple skills for different tools
        let config = DatabaseConfiguration(
            isStoredInMemoryOnly: true,
            allowsSave: true,
            ragFactory: MockRagFactory(mockRag: MockRagging())
        )
        let database = try Database.new(configuration: config)
        try await waitForStatus(database, expectedStatus: .ready)

        _ = try await database.write(
            SkillCommands.Create(
                name: "Web Research",
                skillDescription: "Web research skill",
                instructions: "Search effectively",
                tools: ["duckduckgo_search"]
            )
        )

        _ = try await database.write(
            SkillCommands.Create(
                name: "Code Execution",
                skillDescription: "Python coding skill",
                instructions: "Execute Python code carefully",
                tools: ["python_exec"]
            )
        )

        // When - Query with both tools
        let context = try await database.read(
            SkillCommands.GetSkillContext(toolIdentifiers: Set(["duckduckgo_search", "python_exec"]))
        )

        // Then - Both skills should be included
        #expect(context.activeSkills.count == 2)
        let skillNames = Set(context.activeSkills.map(\.name))
        #expect(skillNames.contains("Web Research"))
        #expect(skillNames.contains("Code Execution"))
    }

    @Test("GetSkillContext returns empty when no tools match")
    func getSkillContextReturnsEmptyForNonMatchingTools() async throws {
        // Given - A skill that doesn't match the query
        let config = DatabaseConfiguration(
            isStoredInMemoryOnly: true,
            allowsSave: true,
            ragFactory: MockRagFactory(mockRag: MockRagging())
        )
        let database = try Database.new(configuration: config)
        try await waitForStatus(database, expectedStatus: .ready)

        _ = try await database.write(
            SkillCommands.Create(
                name: "Web Research",
                skillDescription: "Web research",
                instructions: "Search effectively",
                tools: ["duckduckgo_search"]
            )
        )

        // When - Query with different tools
        let context = try await database.read(
            SkillCommands.GetSkillContext(toolIdentifiers: Set(["python_exec"]))
        )

        // Then - Should be empty
        #expect(context.isEmpty)
        #expect(context.activeSkills.isEmpty)
    }

    @Test("Skill matches multiple tool identifiers")
    func skillMatchesMultipleToolIdentifiers() async throws {
        // Given - A skill with multiple tools
        let config = DatabaseConfiguration(
            isStoredInMemoryOnly: true,
            allowsSave: true,
            ragFactory: MockRagFactory(mockRag: MockRagging())
        )
        let database = try Database.new(configuration: config)
        try await waitForStatus(database, expectedStatus: .ready)

        _ = try await database.write(
            SkillCommands.Create(
                name: "Full Stack Research",
                skillDescription: "Research and code",
                instructions: "Research then implement",
                tools: ["duckduckgo_search", "browser.search", "python_exec"]
            )
        )

        // When - Query with any one of the tools
        let skillsForSearch = try await database.read(
            SkillCommands.GetForTools(toolIdentifiers: Set(["duckduckgo_search"]))
        )
        let skillsForPython = try await database.read(
            SkillCommands.GetForTools(toolIdentifiers: Set(["python_exec"]))
        )
        let skillsForBrowser = try await database.read(
            SkillCommands.GetForTools(toolIdentifiers: Set(["browser.search"]))
        )

        // Then - Same skill should match all
        #expect(skillsForSearch.count == 1)
        #expect(skillsForPython.count == 1)
        #expect(skillsForBrowser.count == 1)
        #expect(skillsForSearch.first?.id == skillsForPython.first?.id)
        #expect(skillsForPython.first?.id == skillsForBrowser.first?.id)
    }

    @Test("SkillData conversion preserves all fields")
    func skillDataConversionPreservesFields() async throws {
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
                name: "Test Skill",
                skillDescription: "Test description",
                instructions: "Test instructions",
                tools: ["tool1", "tool2"]
            )
        )

        // When
        let context = try await database.read(
            SkillCommands.GetSkillContext(toolIdentifiers: Set(["tool1"]))
        )

        // Then - Verify SkillData has all expected fields
        let skillData = context.activeSkills.first
        #expect(skillData != nil)
        #expect(skillData?.id == skillId)
        #expect(skillData?.name == "Test Skill")
        #expect(skillData?.skillDescription == "Test description")
        #expect(skillData?.instructions == "Test instructions")
        #expect(skillData?.tools.contains("tool1") == true)
        #expect(skillData?.tools.contains("tool2") == true)
    }

    @Test("DeleteAllUserSkills removes only user skills")
    func deleteAllUserSkillsRemovesOnlyUserSkills() async throws {
        // Given
        let config = DatabaseConfiguration(
            isStoredInMemoryOnly: true,
            allowsSave: true,
            ragFactory: MockRagFactory(mockRag: MockRagging())
        )
        let database = try Database.new(configuration: config)
        try await waitForStatus(database, expectedStatus: .ready)

        // Create user skill
        _ = try await database.write(
            SkillCommands.Create(
                name: "User Skill",
                skillDescription: "User created",
                instructions: "User instructions"
            )
        )

        // Create system skill
        _ = try await database.write(
            SkillCommands.Create(
                name: "System Skill",
                skillDescription: "System skill",
                instructions: "System instructions",
                isSystem: true
            )
        )

        // When
        _ = try await database.write(SkillCommands.DeleteAllUserSkills())

        // Then - Only system skill should remain
        let allSkills = try await database.read(SkillCommands.GetAll())
        #expect(allSkills.count == 1)
        #expect(allSkills.first?.isSystem == true)
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
