import Foundation
import SwiftData
import OSLog
import Abstractions
import DataAssets

// swiftlint:disable nesting

// MARK: - Personality Commands
    public enum PersonalityCommands {
    /// Creates a new non-default system personality intended to back a single chat session.
    ///
    /// Rationale: `Personality.chat` is a 1:1 relationship. Reusing the default personality would
    /// cause "chat create" to reuse/clear the existing chat instead of creating a new session.
    public struct CreateSessionPersonality: WriteCommand {
        public typealias Result = UUID
        // Mark as custom + attach to the user so AppInitialize personality syncing doesn't
        // treat it as a system personality and delete it (which would cascade-delete its chat).
        public var requiresUser: Bool { true }
        public var requiresRag: Bool { false }

        private let title: String?

        public init(title: String?) {
            self.title = title
        }

        public func execute(
            in context: ModelContext,
            userId: PersistentIdentifier?,
            rag: Ragging?
        ) throws -> UUID {
            guard let userId else {
                throw DatabaseError.userNotFound
            }
            let user = try context.getUser(id: userId)

            let trimmedTitle = title?.trimmingCharacters(in: .whitespacesAndNewlines)
            let name: String
            if let trimmedTitle, !trimmedTitle.isEmpty {
                name = trimmedTitle
            } else {
                name = "Session \(UUID().uuidString.prefix(8))"
            }

            let personality = Personality(
                systemInstruction: .empatheticFriend,
                name: name,
                description: "Ephemeral session assistant",
                imageName: "friend-icon",
                category: .personal,
                isDefault: false,
                isCustom: true,
                user: user
            )
            context.insert(personality)
            try context.save()
            return personality.id
        }
    }

    public struct GetDefault: ReadCommand {
        public typealias Result = UUID
        public var requiresUser: Bool { false }
        public var requiresRag: Bool { false }

        public init() {}

        public func execute(
            in context: ModelContext,
            userId: PersistentIdentifier?,
            rag: Ragging?
        ) throws -> UUID {
            let descriptor = FetchDescriptor<Personality>(
                predicate: #Predicate<Personality> { $0.isDefault == true }
            )
            guard let defaultPersonality = try context.fetch(descriptor).first else {
                Logger.database.error("No default personality found in database")
                throw DatabaseError.personalityNotFound
            }

            return defaultPersonality.id
        }
    }

    public struct Read: ReadCommand {
        public typealias Result = Personality
        public var requiresUser: Bool { false }
        public var requiresRag: Bool { false }

        private let personalityId: UUID

        public init(personalityId: UUID) {
            self.personalityId = personalityId
        }

        public func execute(
            in context: ModelContext,
            userId: PersistentIdentifier?,
            rag: Ragging?
        ) throws -> Personality {
            let descriptor = FetchDescriptor<Personality>(
                predicate: #Predicate<Personality> { $0.id == personalityId }
            )

            guard let personality = try context.fetch(descriptor).first else {
                throw DatabaseError.personalityNotFound
            }

            return personality
        }
    }

    public struct GetAll: ReadCommand {
        public typealias Result = [Personality]
        public var requiresUser: Bool { false }
        public var requiresRag: Bool { false }

        public init() {}

        public func execute(
            in context: ModelContext,
            userId: PersistentIdentifier?,
            rag: Ragging?
        ) throws -> [Personality] {
            let descriptor = FetchDescriptor<Personality>()
            return try context.fetch(descriptor)
        }
    }

    public struct WriteDefault: WriteCommand {
        public typealias Result = UUID
        public var requiresUser: Bool { false }
        public var requiresRag: Bool { false }

        public init() {}

        public func execute(
            in context: ModelContext,
            userId: PersistentIdentifier?,
            rag: Ragging?
        ) throws -> UUID {
            // Check if default personality already exists
            let descriptor = FetchDescriptor<Personality>(
                predicate: #Predicate<Personality> { $0.isDefault == true }
            )

            if let existingDefault = try context.fetch(descriptor).first {
                Logger.database.info("Default personality already exists with ID: \(existingDefault.id)")
                return existingDefault.id
            }

            // Create the default personality
            let defaultPersonality = Personality(
                systemInstruction: .empatheticFriend,
                name: "Buddy",
                description: "A good buddy: upbeat, loyal, and real with you",
                imageName: "friend-icon",
                category: .personal,
                isDefault: true
            )

            // Insert into context
            context.insert(defaultPersonality)

            Logger.database.info("Created default personality with ID: \(defaultPersonality.id)")
            return defaultPersonality.id
        }
    }

    public struct CreateCustom: WriteCommand {
        public typealias Result = UUID
        public var requiresUser: Bool { true }
        public var requiresRag: Bool { false }

        private let name: String
        private let description: String
        private let customSystemInstruction: String
        private let category: PersonalityCategory
        private let tintColorHex: String?
        private let imageName: String?
        private let customImage: Data?

        public init(
            name: String,
            description: String,
            customSystemInstruction: String,
            category: PersonalityCategory,
            tintColorHex: String? = nil,
            imageName: String? = nil,
            customImage: Data? = nil
        ) {
            self.name = name
            self.description = description
            self.customSystemInstruction = customSystemInstruction
            self.category = category
            self.tintColorHex = tintColorHex
            self.imageName = imageName
            self.customImage = customImage
        }

        public func execute(
            in context: ModelContext,
            userId: PersistentIdentifier?,
            rag: Ragging?
        ) throws -> UUID {
            guard let userId = userId else {
                throw DatabaseError.userNotFound
            }

            // Get the user entity
            guard let user = context.model(for: userId) as? User else {
                throw DatabaseError.userNotFound
            }

            // Validate input
            guard !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                throw DatabaseError.invalidInput("Personality name cannot be empty")
            }

            guard !customSystemInstruction.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                throw DatabaseError.invalidInput("System instruction cannot be empty")
            }

            // Optional: Validate system instruction length
            let trimmedInstruction = customSystemInstruction.trimmingCharacters(in: .whitespacesAndNewlines)
            guard trimmedInstruction.count >= 10 else {
                throw DatabaseError.invalidInput("System instruction must be at least 10 characters long")
            }

            guard trimmedInstruction.count <= 5000 else {
                throw DatabaseError.invalidInput("System instruction must be less than 5000 characters")
            }

            // Validate image size if provided
            if let customImage = customImage {
                let maxImageSize = 5 * 1024 * 1024 // 5MB
                guard customImage.count <= maxImageSize else {
                    throw DatabaseError.invalidInput("Image size must be less than 5MB")
                }
            }

            // Create the custom personality using a custom initializer
            let customPersonality: Personality = Personality(
                systemInstruction: .custom(customSystemInstruction),
                name: name,
                description: description,
                imageName: imageName,
                category: category,
                image: nil,
                isCustom: true,
                user: user
            )

            // Insert into context
            context.insert(customPersonality)

            // Create ImageAttachment if image data provided
            if let customImage = customImage {
                let imageAttachment = ImageAttachment(
                    image: customImage,
                    prompt: nil,
                    content: "Custom personality image for \(name)"
                )
                context.insert(imageAttachment)
                customPersonality.customImage = imageAttachment
            }

            try context.save()

            // Note: Chat is created lazily when the personality is selected via GetChat command.
            // This allows personalities to be created even when models haven't been downloaded yet.

            Logger.database.info("Created custom personality \(customPersonality.id) for user: \(user.id)")
            return customPersonality.id
        }
    }

    /// Updates an existing personality's properties
    public struct Update: WriteCommand {
        public var requiresUser: Bool { false }
        public var requiresRag: Bool { false }

        private let personalityId: UUID
        private let name: String?
        private let description: String?
        private let systemInstruction: String?
        private let category: PersonalityCategory?
        private let tintColorHex: String?
        private let imageName: String?
        private let customImage: Data?

        /// Initialize an Update command
        /// - Parameters:
        ///   - personalityId: The ID of the personality to update
        ///   - name: New name (nil to keep existing)
        ///   - description: New description (nil to keep existing)
        ///   - systemInstruction: New system instruction text (nil to keep existing, only for custom)
        ///   - category: New category (nil to keep existing)
        ///   - tintColorHex: New tint color as hex string (nil to keep existing)
        ///   - imageName: New image name (nil to keep existing)
        ///   - customImage: New custom image data (nil to keep existing)
        public init(
            personalityId: UUID,
            name: String? = nil,
            description: String? = nil,
            systemInstruction: String? = nil,
            category: PersonalityCategory? = nil,
            tintColorHex: String? = nil,
            imageName: String? = nil,
            customImage: Data? = nil
        ) {
            self.personalityId = personalityId
            self.name = name
            self.description = description
            self.systemInstruction = systemInstruction
            self.category = category
            self.tintColorHex = tintColorHex
            self.imageName = imageName
            self.customImage = customImage
        }

        public func execute(
            in context: ModelContext,
            userId: PersistentIdentifier?,
            rag: Ragging?
        ) throws -> UUID {
            let personality: Personality = try fetchPersonality(in: context)
            try updateTextProperties(for: personality)
            try updateVisualProperties(for: personality, in: context)
            try context.save()
            Logger.database.info("Updated personality with ID: \(personalityId)")
            return personality.id
        }

        private func fetchPersonality(in context: ModelContext) throws -> Personality {
            let descriptor = FetchDescriptor<Personality>(
                predicate: #Predicate<Personality> { $0.id == personalityId }
            )
            guard let personality = try context.fetch(descriptor).first else {
                Logger.database.error("PersonalityCommands.Update: personality not found")
                throw DatabaseError.personalityNotFound
            }
            return personality
        }

        private func updateTextProperties(for personality: Personality) throws {
            if let name = name {
                let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmedName.isEmpty else {
                    throw DatabaseError.invalidInput("Personality name cannot be empty")
                }
                personality.name = trimmedName
            }

            if let description = description {
                personality.displayDescription = description
            }

            if let systemInstruction = systemInstruction {
                try updateSystemInstruction(systemInstruction, for: personality)
            }

            if let category = category {
                personality.category = category
            }
        }

        private func updateSystemInstruction(_ instruction: String, for personality: Personality) throws {
            let trimmedInstruction = instruction.trimmingCharacters(in: .whitespacesAndNewlines)
            guard trimmedInstruction.count >= 10 else {
                throw DatabaseError.invalidInput("System instruction must be at least 10 characters")
            }
            guard trimmedInstruction.count <= 5000 else {
                throw DatabaseError.invalidInput("System instruction must be less than 5000 characters")
            }
            personality.systemInstruction = .custom(trimmedInstruction)
        }

        private func updateVisualProperties(
            for personality: Personality,
            in context: ModelContext
        ) throws {
            if let tintColorHex = tintColorHex {
                personality.tintColorHex = tintColorHex
            }
            if let imageName = imageName {
                personality.imageName = imageName
            }
            if let customImage = customImage {
                try updateCustomImage(customImage, for: personality, in: context)
            }
        }

        private func updateCustomImage(
            _ imageData: Data,
            for personality: Personality,
            in context: ModelContext
        ) throws {
            let maxImageSize: Int = 5 * 1024 * 1024 // 5MB
            guard imageData.count <= maxImageSize else {
                throw DatabaseError.invalidInput("Image size must be less than 5MB")
            }
            if let oldImage = personality.customImage {
                context.delete(oldImage)
            }
            let imageAttachment = ImageAttachment(
                image: imageData,
                prompt: nil,
                content: "Custom personality image for \(personality.name)"
            )
            context.insert(imageAttachment)
            personality.customImage = imageAttachment
        }
    }

    /// Deletes a custom personality (only custom personalities can be deleted)
    public struct Delete: WriteCommand {
        public var requiresUser: Bool { false }
        public var requiresRag: Bool { false }

        private let personalityId: UUID

        public init(personalityId: UUID) {
            self.personalityId = personalityId
        }

        public func execute(
            in context: ModelContext,
            userId: PersistentIdentifier?,
            rag: Ragging?
        ) throws -> UUID {
            let descriptor = FetchDescriptor<Personality>(
                predicate: #Predicate<Personality> { $0.id == personalityId }
            )

            guard let personality = try context.fetch(descriptor).first else {
                throw DatabaseError.personalityNotFound
            }

            guard personality.isCustom else {
                Logger.database.error("Cannot delete system personality: \(personality.name)")
                throw PersonalityError.cannotEditSystemPersonality
            }

            let deletedId = personality.id
            Logger.database.info("Deleting custom personality with ID: \(personalityId)")
            context.delete(personality)
            try context.save()
            Logger.database.info("Successfully deleted personality with ID: \(personalityId)")
            return deletedId
        }
    }
}
