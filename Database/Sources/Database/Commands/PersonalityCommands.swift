import Foundation
import SwiftData
import OSLog
import Abstractions
import DataAssets

// swiftlint:disable nesting

// MARK: - Personality Commands
public enum PersonalityCommands {
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
                systemInstruction: .englishAssistant,
                name: "Generic Assistant",
                description: "A helpful and knowledgeable assistant",
                imageName: "think",
                category: .productivity,
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

            Logger.database.info("Created custom personality with ID: \(customPersonality.id) for user: \(user.id)")
            return customPersonality.id
        }
    }
}
