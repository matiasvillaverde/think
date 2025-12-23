import Testing
import Foundation
import SwiftData
import Abstractions
@testable import Database
import AbstractionsTestUtilities

@Suite("PersonalityCommands.Update Tests")
@MainActor
struct PersonalityCommandsUpdateTests {
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

        // Insert default personalities
        try await database.execute(InsertDefaultPersonalitiesCommand())

        // Add required models for personality commands that create chats
        try await addRequiredModelsForPersonalityCommands(database)

        return database
    }

    // MARK: - Update Name Tests

    @Test("Update personality name successfully")
    func updatePersonalityName() async throws {
        // Given
        let database = try await createTestDatabaseWithPersonalities()
        let personalities = try await database.read(PersonalityCommands.GetAll())
        let personality = try #require(personalities.first)
        let originalName = personality.name

        // When
        _ = try await database.write(
            PersonalityCommands.Update(
                personalityId: personality.id,
                name: "Updated Name"
            )
        )

        // Then
        let updatedPersonality = try await database.read(
            PersonalityCommands.Read(personalityId: personality.id)
        )
        #expect(updatedPersonality.name == "Updated Name")
        #expect(updatedPersonality.name != originalName)
    }

    // MARK: - Update Description Tests

    @Test("Update personality description successfully")
    func updatePersonalityDescription() async throws {
        // Given
        let database = try await createTestDatabaseWithPersonalities()
        let personalities = try await database.read(PersonalityCommands.GetAll())
        let personality = try #require(personalities.first)

        // When
        _ = try await database.write(
            PersonalityCommands.Update(
                personalityId: personality.id,
                description: "A brand new description"
            )
        )

        // Then
        let updatedPersonality = try await database.read(
            PersonalityCommands.Read(personalityId: personality.id)
        )
        #expect(updatedPersonality.displayDescription == "A brand new description")
    }

    // MARK: - Update System Instruction Tests

    @Test("Update personality system instruction successfully")
    func updatePersonalitySystemInstruction() async throws {
        // Given
        let database = try await createTestDatabaseWithPersonalities()

        // Create a custom personality (system instruction is updatable)
        let customPersonalityId = try await database.write(
            PersonalityCommands.CreateCustom(
                name: "Custom Test",
                description: "A custom personality",
                customSystemInstruction: "You are an initial assistant.",
                category: .productivity
            )
        )

        // When
        _ = try await database.write(
            PersonalityCommands.Update(
                personalityId: customPersonalityId,
                systemInstruction: "You are an updated helpful assistant who loves coding."
            )
        )

        // Then
        let updatedPersonality = try await database.read(
            PersonalityCommands.Read(personalityId: customPersonalityId)
        )
        if case .custom(let instruction) = updatedPersonality.systemInstruction {
            #expect(instruction.contains("updated helpful assistant"))
        } else {
            Issue.record("Expected custom system instruction")
        }
    }

    // MARK: - Update Category Tests

    @Test("Update personality category successfully")
    func updatePersonalityCategory() async throws {
        // Given
        let database = try await createTestDatabaseWithPersonalities()
        let customPersonalityId = try await database.write(
            PersonalityCommands.CreateCustom(
                name: "Custom Test",
                description: "A custom personality",
                customSystemInstruction: "You are a helpful assistant.",
                category: .productivity
            )
        )

        // When
        _ = try await database.write(
            PersonalityCommands.Update(
                personalityId: customPersonalityId,
                category: .creative
            )
        )

        // Then
        let updatedPersonality = try await database.read(
            PersonalityCommands.Read(personalityId: customPersonalityId)
        )
        #expect(updatedPersonality.category == .creative)
    }

    // MARK: - Update Tint Color Tests

    @Test("Update personality tint color successfully")
    func updatePersonalityTintColor() async throws {
        // Given
        let database = try await createTestDatabaseWithPersonalities()
        let personalities = try await database.read(PersonalityCommands.GetAll())
        let personality = try #require(personalities.first)

        // When
        _ = try await database.write(
            PersonalityCommands.Update(
                personalityId: personality.id,
                tintColorHex: "#FF5733"
            )
        )

        // Then
        let updatedPersonality = try await database.read(
            PersonalityCommands.Read(personalityId: personality.id)
        )
        #expect(updatedPersonality.tintColorHex == "#FF5733")
    }

    // MARK: - Update Multiple Fields Tests

    @Test("Update multiple fields at once")
    func updateMultipleFields() async throws {
        // Given
        let database = try await createTestDatabaseWithPersonalities()
        let customPersonalityId = try await database.write(
            PersonalityCommands.CreateCustom(
                name: "Custom Test",
                description: "Original description",
                customSystemInstruction: "Original instruction that is long enough.",
                category: .productivity
            )
        )

        // When
        _ = try await database.write(
            PersonalityCommands.Update(
                personalityId: customPersonalityId,
                name: "New Name",
                description: "New description",
                category: .creative,
                tintColorHex: "#00FF00"
            )
        )

        // Then
        let updatedPersonality = try await database.read(
            PersonalityCommands.Read(personalityId: customPersonalityId)
        )
        #expect(updatedPersonality.name == "New Name")
        #expect(updatedPersonality.displayDescription == "New description")
        #expect(updatedPersonality.category == .creative)
        #expect(updatedPersonality.tintColorHex == "#00FF00")
    }

    // MARK: - Validation Error Tests

    @Test("Update fails for non-existent personality")
    func updateFailsForNonExistent() async throws {
        // Given
        let database = try await createTestDatabaseWithPersonalities()
        let nonExistentId = UUID()

        // When/Then
        do {
            _ = try await database.write(
                PersonalityCommands.Update(
                    personalityId: nonExistentId,
                    name: "New Name"
                )
            )
            Issue.record("Expected personalityNotFound error")
        } catch DatabaseError.personalityNotFound {
            // Expected
        }
    }

    @Test("Update with empty name fails validation")
    func updateWithEmptyNameFails() async throws {
        // Given
        let database = try await createTestDatabaseWithPersonalities()
        let personalities = try await database.read(PersonalityCommands.GetAll())
        let personality = try #require(personalities.first)

        // When/Then
        do {
            _ = try await database.write(
                PersonalityCommands.Update(
                    personalityId: personality.id,
                    name: "   "
                )
            )
            Issue.record("Expected invalidInput error for empty name")
        } catch DatabaseError.invalidInput {
            // Expected
        }
    }

    @Test("Update custom personality system instruction with too short content fails")
    func updateSystemInstructionTooShortFails() async throws {
        // Given
        let database = try await createTestDatabaseWithPersonalities()
        let customPersonalityId = try await database.write(
            PersonalityCommands.CreateCustom(
                name: "Custom Test",
                description: "A custom personality",
                customSystemInstruction: "You are a helpful assistant.",
                category: .productivity
            )
        )

        // When/Then
        do {
            _ = try await database.write(
                PersonalityCommands.Update(
                    personalityId: customPersonalityId,
                    systemInstruction: "Short"
                )
            )
            Issue.record("Expected invalidInput error for short instruction")
        } catch DatabaseError.invalidInput {
            // Expected
        }
    }

    // MARK: - Edge Cases

    @Test("Update with nil values does not change existing values")
    func updateWithNilValuesPreservesExisting() async throws {
        // Given
        let database = try await createTestDatabaseWithPersonalities()
        let customPersonalityId = try await database.write(
            PersonalityCommands.CreateCustom(
                name: "Original Name",
                description: "Original description",
                customSystemInstruction: "Original instruction that is long enough.",
                category: .productivity
            )
        )

        let originalPersonality = try await database.read(
            PersonalityCommands.Read(personalityId: customPersonalityId)
        )

        // When - Update only the name
        _ = try await database.write(
            PersonalityCommands.Update(
                personalityId: customPersonalityId,
                name: "New Name"
            )
        )

        // Then - Other fields should remain unchanged
        let updatedPersonality = try await database.read(
            PersonalityCommands.Read(personalityId: customPersonalityId)
        )
        #expect(updatedPersonality.name == "New Name")
        #expect(updatedPersonality.displayDescription == originalPersonality.displayDescription)
        #expect(updatedPersonality.category == originalPersonality.category)
    }

    @Test("System personalities can be updated (name and description)")
    func systemPersonalitiesCanBeUpdated() async throws {
        // Given
        let database = try await createTestDatabaseWithPersonalities()
        let personalities = try await database.read(PersonalityCommands.GetAll())
        let systemPersonality = try #require(personalities.first { !$0.isCustom })

        // When
        _ = try await database.write(
            PersonalityCommands.Update(
                personalityId: systemPersonality.id,
                name: "My Customized Assistant",
                description: "A personalized version"
            )
        )

        // Then
        let updatedPersonality = try await database.read(
            PersonalityCommands.Read(personalityId: systemPersonality.id)
        )
        #expect(updatedPersonality.name == "My Customized Assistant")
        #expect(updatedPersonality.displayDescription == "A personalized version")
        // System instruction should remain as the predefined type
        #expect(updatedPersonality.isCustom == false)
    }
}
