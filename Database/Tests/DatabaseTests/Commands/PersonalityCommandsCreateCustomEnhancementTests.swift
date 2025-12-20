import Testing
import Foundation
import SwiftData
@testable import Database
import Abstractions
import DataAssets

@Suite("PersonalityCommands.CreateCustom Enhancement Tests")
struct CreateCustomEnhancementTests {
    @Test("creates ImageAttachment when image data provided")
    func testImageAttachmentCreation() throws {
        // Given
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: User.self, Personality.self, ImageAttachment.self, configurations: configuration)
        let context = ModelContext(container)

        // Create a user first
        let user = User()
        context.insert(user)
        try context.save()

        // Create test image data
        let imageData = Data(repeating: 0, count: 1000) // 1KB test image

        // When
        let command = PersonalityCommands.CreateCustom(
            name: "Test Personality",
            description: "Test Description",
            customSystemInstruction: "You are a test assistant",
            category: .productivity,
            customImage: imageData
        )

        let personalityId = try command.execute(
            in: context,
            userId: user.persistentModelID,
            rag: nil
        )

        // Then
        let descriptor = FetchDescriptor<Personality>(
            predicate: #Predicate<Personality> { $0.id == personalityId }
        )
        let personalities = try context.fetch(descriptor)

        #expect(personalities.count == 1)
        let personality = personalities[0]
        #expect(personality.customImage != nil)
        #expect(personality.customImage?.image == imageData)
    }

    @Test("links ImageAttachment to personality")
    func testImageAttachmentRelationship() throws {
        // Given
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: User.self, Personality.self, ImageAttachment.self, configurations: configuration)
        let context = ModelContext(container)

        // Create a user first
        let user = User()
        context.insert(user)
        try context.save()

        // Create test image data
        let imageData = Data(repeating: 0, count: 2000) // 2KB test image

        // When
        let command = PersonalityCommands.CreateCustom(
            name: "Test Personality",
            description: "Test Description",
            customSystemInstruction: "You are a test assistant",
            category: .creative,
            customImage: imageData
        )

        let personalityId = try command.execute(
            in: context,
            userId: user.persistentModelID,
            rag: nil
        )

        // Then
        let personality = try context.fetch(
            FetchDescriptor<Personality>(
                predicate: #Predicate<Personality> { $0.id == personalityId }
            )
        ).first

        #expect(personality != nil)
        #expect(personality?.customImage != nil)

        // Verify the relationship is properly set
        let imageAttachment = personality?.customImage
        #expect(imageAttachment?.image.count == 2000)
    }

    @Test("validates image size limit (5MB)")
    func testImageSizeValidation() throws {
        // Given
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: User.self, Personality.self, ImageAttachment.self, configurations: configuration)
        let context = ModelContext(container)

        // Create a user first
        let user = User()
        context.insert(user)
        try context.save()

        // Create image data larger than 5MB
        let largeImageData = Data(repeating: 0, count: 6 * 1024 * 1024) // 6MB

        // When/Then
        let command = PersonalityCommands.CreateCustom(
            name: "Test Personality",
            description: "Test Description",
            customSystemInstruction: "You are a test assistant",
            category: .productivity,
            customImage: largeImageData
        )

        #expect(throws: DatabaseError.self) {
            try command.execute(
                in: context,
                userId: user.persistentModelID,
                rag: nil
            )
        }
    }

    @Test("creates personality without image when no image data provided")
    func testNoImageCreation() throws {
        // Given
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: User.self, Personality.self, ImageAttachment.self, configurations: configuration)
        let context = ModelContext(container)

        // Create a user first
        let user = User()
        context.insert(user)
        try context.save()

        // When
        let command = PersonalityCommands.CreateCustom(
            name: "Test Personality",
            description: "Test Description",
            customSystemInstruction: "You are a test assistant",
            category: .productivity,
            customImage: nil
        )

        let personalityId = try command.execute(
            in: context,
            userId: user.persistentModelID,
            rag: nil
        )

        // Then
        let personality = try context.fetch(
            FetchDescriptor<Personality>(
                predicate: #Predicate<Personality> { $0.id == personalityId }
            )
        ).first

        #expect(personality != nil)
        #expect(personality?.customImage == nil)
    }

    @Test("preserves existing functionality without image")
    func testBackwardCompatibility() throws {
        // Given
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: User.self, Personality.self, ImageAttachment.self, configurations: configuration)
        let context = ModelContext(container)

        // Create a user first
        let user = User()
        context.insert(user)
        try context.save()

        // When - Create personality the old way (without image)
        let command = PersonalityCommands.CreateCustom(
            name: "Old Style Personality",
            description: "Created without image",
            customSystemInstruction: "You are a helpful assistant",
            category: .productivity
        )

        let personalityId = try command.execute(
            in: context,
            userId: user.persistentModelID,
            rag: nil
        )

        // Then
        let personality = try context.fetch(
            FetchDescriptor<Personality>(
                predicate: #Predicate<Personality> { $0.id == personalityId }
            )
        ).first

        #expect(personality != nil)
        #expect(personality?.name == "Old Style Personality")
        #expect(personality?.customImage == nil)
        #expect(personality?.isCustom == true)
    }
}
