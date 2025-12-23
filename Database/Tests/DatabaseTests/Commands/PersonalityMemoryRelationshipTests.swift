import Testing
import Foundation
import SwiftData
import Abstractions
@testable import Database
import AbstractionsTestUtilities

@Suite("Personality-Memory Relationship Tests")
@MainActor
struct PersonalityMemoryRelationshipTests {
    // MARK: - Helper Methods

    /// Creates a test database with default personalities inserted
    private func createTestDatabaseWithPersonalities() async throws -> Database {
        let config = DatabaseConfiguration(
            isStoredInMemoryOnly: true,
            allowsSave: true,
            ragFactory: MockRagFactory(mockRag: MockRagging())
        )
        let database = try Database.new(configuration: config)
        try await waitForStatus(database, expectedStatus: .ready)

        // Insert default personalities (normally done by AppInitializeCommand)
        try await database.execute(InsertDefaultPersonalitiesCommand())

        // Add required models for personality commands that create chats
        try await addRequiredModelsForPersonalityCommands(database)

        return database
    }

    // MARK: - Relationship Tests

    @Test("Personality can have associated memories")
    func personalityCanHaveMemories() async throws {
        // Given
        let database = try await createTestDatabaseWithPersonalities()

        // Get a personality
        let personalities = try await database.read(PersonalityCommands.GetAll())
        let personality = try #require(personalities.first)

        // When - Create a soul memory for the personality
        let soulId = try await database.write(
            MemoryCommands.UpsertPersonalitySoul(
                personalityId: personality.id,
                content: "I am a friendly coding assistant who loves Swift."
            )
        )

        // Then
        let memory = try await database.read(MemoryCommands.Read(memoryId: soulId))
        #expect(memory.type == .soul)
        #expect(memory.content == "I am a friendly coding assistant who loves Swift.")
        #expect(memory.personality?.id == personality.id)
    }

    @Test("Different personalities have different souls")
    func differentPersonalitiesHaveDifferentSouls() async throws {
        // Given
        let database = try await createTestDatabaseWithPersonalities()

        // Get two different personalities
        let personalities = try await database.read(PersonalityCommands.GetAll())
        #expect(personalities.count >= 2, "Need at least 2 personalities for this test")
        let personality1 = personalities[0]
        let personality2 = personalities[1]

        // When - Create souls for both personalities
        let soul1Id = try await database.write(
            MemoryCommands.UpsertPersonalitySoul(
                personalityId: personality1.id,
                content: "I am personality one - creative and artistic."
            )
        )

        let soul2Id = try await database.write(
            MemoryCommands.UpsertPersonalitySoul(
                personalityId: personality2.id,
                content: "I am personality two - analytical and precise."
            )
        )

        // Then - Each personality has its own soul
        #expect(soul1Id != soul2Id)

        let memory1 = try await database.read(MemoryCommands.Read(memoryId: soul1Id))
        let memory2 = try await database.read(MemoryCommands.Read(memoryId: soul2Id))

        #expect(memory1.personality?.id == personality1.id)
        #expect(memory2.personality?.id == personality2.id)
        #expect(memory1.content.contains("creative"))
        #expect(memory2.content.contains("analytical"))
    }

    @Test("Cascade delete of personality removes its memories")
    func cascadeDeleteRemovesMemories() async throws {
        // Given
        let config = DatabaseConfiguration(
            isStoredInMemoryOnly: true,
            allowsSave: true,
            ragFactory: MockRagFactory(mockRag: MockRagging())
        )
        let database = try Database.new(configuration: config)
        try await waitForStatus(database, expectedStatus: .ready)

        // Add required models for personality commands that create chats
        try await addRequiredModelsForPersonalityCommands(database)

        // Create a custom personality
        let personalityId = try await database.write(
            PersonalityCommands.CreateCustom(
                name: "Test Custom Personality",
                description: "A test personality for deletion",
                customSystemInstruction: "You are a test assistant that will be deleted.",
                category: .productivity
            )
        )

        // Create memories for this personality
        let soulId = try await database.write(
            MemoryCommands.UpsertPersonalitySoul(
                personalityId: personalityId,
                content: "I am the soul of the test personality"
            )
        )

        _ = try await database.write(
            MemoryCommands.CreatePersonalityMemory(
                personalityId: personalityId,
                type: .longTerm,
                content: "This is a long-term memory for the test personality"
            )
        )

        // Verify memories exist
        let memoryBefore = try await database.read(MemoryCommands.Read(memoryId: soulId))
        #expect(memoryBefore.personality?.id == personalityId)

        // When - Delete the personality
        _ = try await database.write(PersonalityCommands.Delete(personalityId: personalityId))

        // Then - Memory should be deleted via cascade
        do {
            _ = try await database.read(MemoryCommands.Read(memoryId: soulId))
            Issue.record("Expected memoryNotFound error after personality deletion")
        } catch DatabaseError.memoryNotFound {
            // Expected - cascade delete worked
        }
    }

    // MARK: - Personality Soul Computed Property Tests

    @Test("Personality soul computed property returns associated soul memory")
    func personalitySoulComputedProperty() async throws {
        // Given
        let database = try await createTestDatabaseWithPersonalities()

        let personalities = try await database.read(PersonalityCommands.GetAll())
        let personality = try #require(personalities.first)

        // When - Create a soul for the personality
        _ = try await database.write(
            MemoryCommands.UpsertPersonalitySoul(
                personalityId: personality.id,
                content: "I am a soul defined in the test"
            )
        )

        // Then - Refetch personality and check soul property
        let updatedPersonality = try await database.read(
            PersonalityCommands.Read(personalityId: personality.id)
        )
        #expect(updatedPersonality.soul != nil)
        #expect(updatedPersonality.soul?.content == "I am a soul defined in the test")
    }

    // MARK: - Editability Tests

    @Test("All personalities are editable")
    func allPersonalitiesAreEditable() async throws {
        // Given
        let database = try await createTestDatabaseWithPersonalities()

        // When
        let personalities = try await database.read(PersonalityCommands.GetAll())

        // Then - All personalities should be editable
        #expect(!personalities.isEmpty, "Should have personalities to test")
        for personality in personalities {
            #expect(personality.isEditable == true, "Personality \(personality.name) should be editable")
        }
    }

    @Test("Only custom personalities are deletable")
    func onlyCustomPersonalitiesAreDeletable() async throws {
        // Given
        let database = try await createTestDatabaseWithPersonalities()

        // Create a custom personality
        let customPersonalityId = try await database.write(
            PersonalityCommands.CreateCustom(
                name: "Deletable Custom",
                description: "This one can be deleted",
                customSystemInstruction: "You are a custom assistant that can be deleted.",
                category: .productivity
            )
        )

        // When
        let personalities = try await database.read(PersonalityCommands.GetAll())
        let customPersonality = try #require(personalities.first { $0.id == customPersonalityId })
        let systemPersonality = try #require(personalities.first { !$0.isCustom })

        // Then
        #expect(customPersonality.isDeletable == true)
        #expect(systemPersonality.isDeletable == false)
    }

    // MARK: - Memory Context Tests

    @Test("Get personality memory context returns all memory types")
    func getPersonalityMemoryContext() async throws {
        // Given
        let database = try await createTestDatabaseWithPersonalities()

        let personalities = try await database.read(PersonalityCommands.GetAll())
        let personality = try #require(personalities.first)

        // Create soul for personality
        _ = try await database.write(
            MemoryCommands.UpsertPersonalitySoul(
                personalityId: personality.id,
                content: "I am the personality soul"
            )
        )

        // Create long-term memory for personality
        _ = try await database.write(
            MemoryCommands.CreatePersonalityMemory(
                personalityId: personality.id,
                type: .longTerm,
                content: "User prefers concise responses"
            )
        )

        // Create daily log for personality
        _ = try await database.write(
            MemoryCommands.AppendToPersonalityDaily(
                personalityId: personality.id,
                content: "Had a productive coding session"
            )
        )

        // When
        let context = try await database.read(
            MemoryCommands.GetPersonalityMemoryContext(
                personalityId: personality.id,
                dailyLogDays: 2
            )
        )

        // Then
        #expect(context.soul != nil)
        #expect(context.soul?.content == "I am the personality soul")
        #expect(context.longTermMemories.count == 1)
        #expect(context.longTermMemories.first?.content == "User prefers concise responses")
        #expect(context.recentDailyLogs.count == 1)
        #expect(!context.isEmpty)
    }

    @Test("Updating personality soul replaces existing soul")
    func updatePersonalitySoulReplacesExisting() async throws {
        // Given
        let database = try await createTestDatabaseWithPersonalities()

        let personalities = try await database.read(PersonalityCommands.GetAll())
        let personality = try #require(personalities.first)

        // Create initial soul
        let firstSoulId = try await database.write(
            MemoryCommands.UpsertPersonalitySoul(
                personalityId: personality.id,
                content: "Initial soul content"
            )
        )

        // When - Update soul
        let secondSoulId = try await database.write(
            MemoryCommands.UpsertPersonalitySoul(
                personalityId: personality.id,
                content: "Updated soul content"
            )
        )

        // Then - Same ID (upsert), content updated
        #expect(firstSoulId == secondSoulId)

        let soul = try await database.read(MemoryCommands.Read(memoryId: firstSoulId))
        #expect(soul.content == "Updated soul content")
    }
}
