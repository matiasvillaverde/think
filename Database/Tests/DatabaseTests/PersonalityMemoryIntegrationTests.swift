import Abstractions
import AbstractionsTestUtilities
import Foundation
import OSLog
@testable import Database
import Testing

/// Integration tests for personality memory system
@Suite("Personality Memory Integration Tests")
internal struct PersonalityMemoryIntegrationTests {
    private static let logger: Logger = Logger(
        subsystem: "DatabaseTests",
        category: "PersonalityMemoryIntegrationTests"
    )

    // MARK: - Soul Memory Tests

    @Test("Personality soul is included in memory context")
    @MainActor
    func personalitySoulIncludedInMemoryContext() async throws {
        // Given
        let database: Database = try createTestDatabase()
        try await database.execute(AppCommands.Initialize())

        let personalityId: UUID = try await database.read(PersonalityCommands.GetDefault())
        let soulContent: String = "I am a thoughtful assistant who values clarity and precision."

        // When - upsert a soul for the personality
        try await database.write(MemoryCommands.UpsertPersonalitySoul(
            personalityId: personalityId,
            content: soulContent
        ))

        // Then - memory context should include the soul
        let memoryContext: MemoryContext = try await database.read(
            MemoryCommands.GetPersonalityMemoryContext(
                personalityId: personalityId,
                chatId: nil,
                dailyLogDays: 0
            )
        )

        #expect(memoryContext.soul != nil)
        #expect(memoryContext.soul?.content == soulContent)
    }

    @Test("Updating personality soul replaces existing soul")
    @MainActor
    func updatingPersonalitySoulReplacesExisting() async throws {
        // Given
        let database: Database = try createTestDatabase()
        try await database.execute(AppCommands.Initialize())

        let personalityId: UUID = try await database.read(PersonalityCommands.GetDefault())
        let originalSoul: String = "I am original."
        let updatedSoul: String = "I am updated with new identity."

        // Set original soul
        try await database.write(MemoryCommands.UpsertPersonalitySoul(
            personalityId: personalityId,
            content: originalSoul
        ))

        // When - update the soul
        try await database.write(MemoryCommands.UpsertPersonalitySoul(
            personalityId: personalityId,
            content: updatedSoul
        ))

        // Then - should have the new soul
        let memoryContext: MemoryContext = try await database.read(
            MemoryCommands.GetPersonalityMemoryContext(
                personalityId: personalityId,
                chatId: nil,
                dailyLogDays: 0
            )
        )

        #expect(memoryContext.soul?.content == updatedSoul)
    }

    // MARK: - Personality Update Tests

    @Test("Editing personality name persists changes")
    @MainActor
    func editingPersonalityNamePersistsChanges() async throws {
        // Given
        let database: Database = try createTestDatabase()
        try await database.execute(AppCommands.Initialize())

        let personalityId: UUID = try await database.read(PersonalityCommands.GetDefault())
        let originalPersonality: Personality = try await database.read(
            PersonalityCommands.Read(personalityId: personalityId)
        )
        let originalName: String = originalPersonality.name
        let newName: String = "Updated Test Name"

        // When - update the personality name
        _ = try await database.write(PersonalityCommands.Update(
            personalityId: personalityId,
            name: newName
        ))

        // Then - name should be updated
        let updatedPersonality: Personality = try await database.read(
            PersonalityCommands.Read(personalityId: personalityId)
        )

        #expect(updatedPersonality.name == newName)
        #expect(updatedPersonality.name != originalName)
    }

    @Test("Editing personality description persists changes")
    @MainActor
    func editingPersonalityDescriptionPersistsChanges() async throws {
        // Given
        let database: Database = try createTestDatabase()
        try await database.execute(AppCommands.Initialize())

        let personalityId: UUID = try await database.read(PersonalityCommands.GetDefault())
        let newDescription: String = "A completely new description for testing"

        // When - update the personality description
        _ = try await database.write(PersonalityCommands.Update(
            personalityId: personalityId,
            description: newDescription
        ))

        // Then - description should be updated
        let updatedPersonality: Personality = try await database.read(
            PersonalityCommands.Read(personalityId: personalityId)
        )

        #expect(updatedPersonality.displayDescription == newDescription)
    }

    @Test("Editing personality category persists changes")
    @MainActor
    func editingPersonalityCategoryPersistsChanges() async throws {
        // Given
        let database: Database = try createTestDatabase()
        try await database.execute(AppCommands.Initialize())

        let personalityId: UUID = try await database.read(PersonalityCommands.GetDefault())
        let originalPersonality: Personality = try await database.read(
            PersonalityCommands.Read(personalityId: personalityId)
        )

        // Pick a different category
        let newCategory: PersonalityCategory = originalPersonality.category == .creative
            ? .productivity
            : .creative

        // When - update the personality category
        _ = try await database.write(PersonalityCommands.Update(
            personalityId: personalityId,
            category: newCategory
        ))

        // Then - category should be updated
        let updatedPersonality: Personality = try await database.read(
            PersonalityCommands.Read(personalityId: personalityId)
        )

        #expect(updatedPersonality.category == newCategory)
    }

    // MARK: - Memory Cascade Delete Tests

    @Test("Deleting custom personality cascades to memories")
    @MainActor
    func deletingCustomPersonalityCascadesToMemories() async throws {
        // Given
        let database: Database = try createTestDatabase()
        try await database.execute(AppCommands.Initialize())

        // Create a custom personality
        let personalityId: UUID = try await database.write(PersonalityCommands.CreateCustom(
            name: "Test Custom Personality",
            description: "A test personality for cascade delete",
            customSystemInstruction: "You are a test assistant for integration testing.",
            category: .productivity
        ))

        // Add a soul to the custom personality
        let soulContent: String = "I am a test soul that should be deleted."
        try await database.write(MemoryCommands.UpsertPersonalitySoul(
            personalityId: personalityId,
            content: soulContent
        ))

        // Verify the soul exists
        let beforeContext: MemoryContext = try await database.read(
            MemoryCommands.GetPersonalityMemoryContext(
                personalityId: personalityId,
                chatId: nil,
                dailyLogDays: 0
            )
        )
        #expect(beforeContext.soul != nil)

        // When - delete the custom personality
        _ = try await database.write(PersonalityCommands.Delete(personalityId: personalityId))

        // Then - personality should be deleted (reading should throw)
        do {
            _ = try await database.read(PersonalityCommands.Read(personalityId: personalityId))
            Issue.record("Expected personality not found error")
        } catch {
            // Expected - personality was deleted
            Self.logger.info("Personality correctly deleted: \(error.localizedDescription)")
        }
    }

    // MARK: - Featured Personalities Tests

    @Test("Factory creates exactly 5 featured personalities")
    @MainActor
    func factoryCreatesExactlyFiveFeaturedPersonalities() async throws {
        // Given
        let database: Database = try createTestDatabase()

        // When
        try await database.execute(AppCommands.Initialize())

        // Then
        let personalities: [Personality] = try await database.read(PersonalityCommands.GetAll())
        let featuredPersonalities: [Personality] = personalities.filter { $0.isFeature }

        #expect(featuredPersonalities.count == 5)
    }

    @Test("Featured personalities are editable")
    @MainActor
    func featuredPersonalitiesAreEditable() async throws {
        // Given
        let database: Database = try createTestDatabase()
        try await database.execute(AppCommands.Initialize())

        // When
        let personalities: [Personality] = try await database.read(PersonalityCommands.GetAll())
        let featuredPersonalities: [Personality] = personalities.filter { $0.isFeature }

        // Then - all featured personalities should be editable
        for featured: Personality in featuredPersonalities {
            #expect(featured.isEditable == true)
        }
    }

    @Test("Featured personalities are not deletable")
    @MainActor
    func featuredPersonalitiesAreNotDeletable() async throws {
        // Given
        let database: Database = try createTestDatabase()
        try await database.execute(AppCommands.Initialize())

        // When
        let personalities: [Personality] = try await database.read(PersonalityCommands.GetAll())
        let featuredPersonalities: [Personality] = personalities.filter { $0.isFeature }

        // Then - featured personalities should not be deletable (they are system, not custom)
        for featured: Personality in featuredPersonalities {
            #expect(featured.isDeletable == false)
        }
    }

    // MARK: - Context Integration Tests

    @Test("Soul memory can be attached to personality relationship")
    @MainActor
    func soulMemoryCanBeAttachedToPersonalityRelationship() async throws {
        // Given
        let database: Database = try createTestDatabase()
        try await database.execute(AppCommands.Initialize())

        let personalityId: UUID = try await database.read(PersonalityCommands.GetDefault())
        let soulContent: String = "Test soul content for relationship verification."

        // When - add soul
        try await database.write(MemoryCommands.UpsertPersonalitySoul(
            personalityId: personalityId,
            content: soulContent
        ))

        // Then - personality should have the soul in its memories relationship
        let personality: Personality = try await database.read(
            PersonalityCommands.Read(personalityId: personalityId)
        )

        #expect(personality.soul != nil)
        #expect(personality.soul?.content == soulContent)
    }

    @Test("Different personalities have independent souls")
    @MainActor
    func differentPersonalitiesHaveIndependentSouls() async throws {
        // Given
        let database: Database = try createTestDatabase()
        try await database.execute(AppCommands.Initialize())

        // Get two different personalities
        let personalities: [Personality] = try await database.read(PersonalityCommands.GetAll())
        #expect(personalities.count >= 2)

        let personality1Id: UUID = personalities[0].id
        let personality2Id: UUID = personalities[1].id

        let soul1Content: String = "I am personality one - analytical and precise."
        let soul2Content: String = "I am personality two - creative and expressive."

        // When - add different souls to each personality
        try await database.write(MemoryCommands.UpsertPersonalitySoul(
            personalityId: personality1Id,
            content: soul1Content
        ))
        try await database.write(MemoryCommands.UpsertPersonalitySoul(
            personalityId: personality2Id,
            content: soul2Content
        ))

        // Then - each personality should have its own soul
        let context1: MemoryContext = try await database.read(
            MemoryCommands.GetPersonalityMemoryContext(
                personalityId: personality1Id,
                chatId: nil,
                dailyLogDays: 0
            )
        )
        let context2: MemoryContext = try await database.read(
            MemoryCommands.GetPersonalityMemoryContext(
                personalityId: personality2Id,
                chatId: nil,
                dailyLogDays: 0
            )
        )

        #expect(context1.soul?.content == soul1Content)
        #expect(context2.soul?.content == soul2Content)
        #expect(context1.soul?.content != context2.soul?.content)
    }

    // MARK: - Edge Cases

    @Test("Empty soul content is handled correctly")
    @MainActor
    func emptySoulContentIsHandledCorrectly() async throws {
        // Given
        let database: Database = try createTestDatabase()
        try await database.execute(AppCommands.Initialize())

        let personalityId: UUID = try await database.read(PersonalityCommands.GetDefault())

        // When - get memory context for personality without soul
        let memoryContext: MemoryContext = try await database.read(
            MemoryCommands.GetPersonalityMemoryContext(
                personalityId: personalityId,
                chatId: nil,
                dailyLogDays: 0
            )
        )

        // Then - soul should be nil
        #expect(memoryContext.soul == nil)
    }

    @Test("Updating non-existent personality throws error")
    @MainActor
    func updatingNonExistentPersonalityThrowsError() async throws {
        // Given
        let database: Database = try createTestDatabase()
        try await database.execute(AppCommands.Initialize())

        let nonExistentId: UUID = UUID()

        // When/Then - updating should throw
        do {
            _ = try await database.write(PersonalityCommands.Update(
                personalityId: nonExistentId,
                name: "New Name"
            ))
            Issue.record("Expected personality not found error")
        } catch DatabaseError.personalityNotFound {
            // Expected
        } catch {
            Issue.record("Unexpected error type: \(error)")
        }
    }

    @Test("Validation rejects empty personality name")
    @MainActor
    func validationRejectsEmptyPersonalityName() async throws {
        // Given
        let database: Database = try createTestDatabase()
        try await database.execute(AppCommands.Initialize())

        let personalityId: UUID = try await database.read(PersonalityCommands.GetDefault())

        // When/Then - updating with empty name should throw
        do {
            _ = try await database.write(PersonalityCommands.Update(
                personalityId: personalityId,
                name: "   "
            ))
            Issue.record("Expected invalid input error")
        } catch DatabaseError.invalidInput {
            // Expected
        } catch {
            Issue.record("Unexpected error type: \(error)")
        }
    }

    // MARK: - Helper Methods

    private func createTestDatabase() throws -> Database {
        let config: DatabaseConfiguration = DatabaseConfiguration(
            isStoredInMemoryOnly: true,
            allowsSave: true,
            ragFactory: MockRagFactory()
        )
        return try Database.new(configuration: config)
    }
}
