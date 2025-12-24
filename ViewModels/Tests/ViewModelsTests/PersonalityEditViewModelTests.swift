import Abstractions
import AbstractionsTestUtilities
@testable import Database
import Foundation
import Testing
@testable import ViewModels

/// Tests for PersonalityEditViewModel
@Suite("PersonalityEditViewModel Tests")
internal struct PersonalityEditViewModelTests {
    // MARK: - Loading Tests

    @Test("Load existing personality data populates form fields")
    @MainActor
    func loadExistingPersonalityDataPopulatesFormFields() async throws {
        // Given
        let database: Database = try createTestDatabase()
        let personalityId: UUID = try await createTestPersonality(in: database)
        let viewModel: PersonalityEditViewModel = PersonalityEditViewModel(
            database: database,
            personalityId: personalityId
        )

        // When
        await viewModel.loadPersonality()

        // Then
        #expect(!viewModel.name.isEmpty)
        #expect(!viewModel.description.isEmpty)
    }

    @Test("Load personality with soul populates soul field")
    @MainActor
    func loadPersonalityWithSoulPopulatesSoulField() async throws {
        // Given
        let database: Database = try createTestDatabase()
        let personalityId: UUID = try await createTestPersonality(in: database)
        let soulContent: String = "I am a thoughtful assistant who values clarity and precision."

        // Create soul for the personality
        try await database.write(MemoryCommands.UpsertPersonalitySoul(
            personalityId: personalityId,
            content: soulContent
        ))

        let viewModel: PersonalityEditViewModel = PersonalityEditViewModel(
            database: database,
            personalityId: personalityId
        )

        // When
        await viewModel.loadPersonality()

        // Then
        #expect(viewModel.soul == soulContent)
    }

    // MARK: - Validation Tests

    @Test("Empty name validation fails")
    @MainActor
    func emptyNameValidationFails() async throws {
        // Given
        let database: Database = try createTestDatabase()
        let personalityId: UUID = try await createTestPersonality(in: database)
        let viewModel: PersonalityEditViewModel = PersonalityEditViewModel(
            database: database,
            personalityId: personalityId
        )
        await viewModel.loadPersonality()
        viewModel.setName("")

        // When
        let result: Bool = await viewModel.updatePersonality()

        // Then
        #expect(result == false)
        #expect(viewModel.validationError != nil)
    }

    @Test("Valid form passes validation")
    @MainActor
    func validFormPassesValidation() async throws {
        // Given
        let database: Database = try createTestDatabase()
        let personalityId: UUID = try await createTestPersonality(in: database)
        let viewModel: PersonalityEditViewModel = PersonalityEditViewModel(
            database: database,
            personalityId: personalityId
        )
        await viewModel.loadPersonality()
        viewModel.setName("Updated Name")
        viewModel.setDescription("Updated description")

        // When
        let result: Bool = await viewModel.updatePersonality()

        // Then
        #expect(result == true)
        #expect(viewModel.validationError == nil)
    }

    // MARK: - Update Tests

    @Test("Update personality calls database command")
    @MainActor
    func updatePersonalityCallsDatabaseCommand() async throws {
        // Given
        let database: Database = try createTestDatabase()
        let personalityId: UUID = try await createTestPersonality(in: database)
        let viewModel: PersonalityEditViewModel = PersonalityEditViewModel(
            database: database,
            personalityId: personalityId
        )
        await viewModel.loadPersonality()

        let newName: String = "Updated Test Name"
        viewModel.setName(newName)

        // When
        let result: Bool = await viewModel.updatePersonality()

        // Then
        #expect(result == true)

        // Verify the change persisted
        let updatedPersonality: Personality = try await database.read(
            PersonalityCommands.Read(personalityId: personalityId)
        )
        #expect(updatedPersonality.name == newName)
    }

    @Test("Update soul updates personality memory")
    @MainActor
    func updateSoulUpdatesPersonalityMemory() async throws {
        // Given
        let database: Database = try createTestDatabase()
        let personalityId: UUID = try await createTestPersonality(in: database)
        let viewModel: PersonalityEditViewModel = PersonalityEditViewModel(
            database: database,
            personalityId: personalityId
        )
        await viewModel.loadPersonality()

        let newSoul: String = "I am an updated thoughtful assistant."
        viewModel.setSoul(newSoul)

        // When
        let result: Bool = await viewModel.updatePersonality()

        // Then
        #expect(result == true)

        // Verify the soul persisted
        let memoryContext: MemoryContext = try await database.read(
            MemoryCommands.GetPersonalityMemoryContext(
                personalityId: personalityId,
                chatId: nil,
                dailyLogDays: 0
            )
        )
        #expect(memoryContext.soul?.content == newSoul)
    }

    @Test("Dismiss flag set after successful update")
    @MainActor
    func dismissFlagSetAfterSuccessfulUpdate() async throws {
        // Given
        let database: Database = try createTestDatabase()
        let personalityId: UUID = try await createTestPersonality(in: database)
        let viewModel: PersonalityEditViewModel = PersonalityEditViewModel(
            database: database,
            personalityId: personalityId
        )
        await viewModel.loadPersonality()

        // When
        let result: Bool = await viewModel.updatePersonality()

        // Then
        #expect(result == true)
        #expect(viewModel.shouldDismiss == true)
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

    private func createTestPersonality(in database: Database) async throws -> UUID {
        // Initialize database to get default personalities
        _ = try await database.execute(AppCommands.Initialize())

        // Get the default personality ID
        return try await database.read(PersonalityCommands.GetDefault())
    }
}
