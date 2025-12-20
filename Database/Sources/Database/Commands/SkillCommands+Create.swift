import Foundation
import SwiftData
import OSLog
import Abstractions

// MARK: - Skill Creation Commands
extension SkillCommands {
    /// Creates a new skill
    public struct Create: WriteCommand {
        private let name: String
        private let skillDescription: String
        private let instructions: String
        private let tools: [String]
        private let isSystem: Bool
        private let isEnabled: Bool
        private let chatId: UUID?

        public var requiresUser: Bool { true }
        public var requiresRag: Bool { false }

        /// Initialize a Create command
        /// - Parameters:
        ///   - name: Display name of the skill
        ///   - skillDescription: Brief description of what the skill does
        ///   - instructions: Markdown instructions for tool usage
        ///   - tools: Tool identifiers this skill relates to
        ///   - isSystem: Whether this is a system-provided skill
        ///   - isEnabled: Whether the skill is enabled
        ///   - chatId: Optional chat association (nil for global skills)
        public init(
            name: String,
            skillDescription: String,
            instructions: String,
            tools: [String] = [],
            isSystem: Bool = false,
            isEnabled: Bool = true,
            chatId: UUID? = nil
        ) {
            self.name = name
            self.skillDescription = skillDescription
            self.instructions = instructions
            self.tools = tools
            self.isSystem = isSystem
            self.isEnabled = isEnabled
            self.chatId = chatId
            Logger.database.info("SkillCommands.Create initialized with name: \(name)")
        }

        public func execute(
            in context: ModelContext,
            userId: PersistentIdentifier?,
            rag: Ragging?
        ) throws -> UUID {
            Logger.database.info("SkillCommands.Create.execute started")

            guard let userId else {
                Logger.database.error("SkillCommands.Create.execute failed: user not found")
                throw DatabaseError.userNotFound
            }

            Logger.database.info("Fetching user with id: \(userId.id.hashValue)")
            let user = try context.getUser(id: userId)
            Logger.database.info("Successfully fetched user: \(user.id)")

            // Find chat if chatId is provided
            var chat: Chat?
            if let chatId {
                let chatDescriptor = FetchDescriptor<Chat>(
                    predicate: #Predicate<Chat> { $0.id == chatId }
                )
                chat = try context.fetch(chatDescriptor).first
                if chat == nil {
                    Logger.database.warning("Chat not found for skill, creating global skill")
                }
            }

            Logger.database.info("Creating new skill: \(name)")
            let skill = Skill(
                name: name,
                skillDescription: skillDescription,
                instructions: instructions,
                tools: tools,
                isSystem: isSystem,
                isEnabled: isEnabled,
                chat: chat,
                user: user
            )
            context.insert(skill)

            Logger.database.info("Saving context changes")
            try context.save()

            Logger.database.info("SkillCommands.Create.execute completed - skill id: \(skill.id)")
            return skill.id
        }
    }

    /// Creates or updates a skill by name (for bundled skills)
    public struct Upsert: WriteCommand {
        private let name: String
        private let skillDescription: String
        private let instructions: String
        private let tools: [String]
        private let isSystem: Bool

        public var requiresUser: Bool { true }
        public var requiresRag: Bool { false }

        /// Initialize an Upsert command
        /// - Parameters:
        ///   - name: Display name of the skill
        ///   - skillDescription: Brief description of what the skill does
        ///   - instructions: Markdown instructions for tool usage
        ///   - tools: Tool identifiers this skill relates to
        ///   - isSystem: Whether this is a system-provided skill
        public init(
            name: String,
            skillDescription: String,
            instructions: String,
            tools: [String] = [],
            isSystem: Bool = true
        ) {
            self.name = name
            self.skillDescription = skillDescription
            self.instructions = instructions
            self.tools = tools
            self.isSystem = isSystem
            Logger.database.info("SkillCommands.Upsert initialized with name: \(name)")
        }

        public func execute(
            in context: ModelContext,
            userId: PersistentIdentifier?,
            rag: Ragging?
        ) throws -> UUID {
            Logger.database.info("SkillCommands.Upsert.execute started")

            guard let userId else {
                Logger.database.error("SkillCommands.Upsert.execute failed: user not found")
                throw DatabaseError.userNotFound
            }

            let user = try context.getUser(id: userId)

            // Try to find existing skill by name for this user
            let descriptor = FetchDescriptor<Skill>(
                predicate: #Predicate<Skill> { skill in
                    skill.name == name && skill.chat == nil
                }
            )
            let existingSkills = try context.fetch(descriptor)
            let existingSkill = existingSkills.first { $0.user?.id == user.id }

            if let existingSkill {
                Logger.database.info("Updating existing skill: \(existingSkill.id)")
                existingSkill.skillDescription = skillDescription
                existingSkill.instructions = instructions
                existingSkill.tools = tools
                existingSkill.updatedAt = Date()
                try context.save()
                return existingSkill.id
            } else {
                Logger.database.info("Creating new skill: \(name)")
                let skill = Skill(
                    name: name,
                    skillDescription: skillDescription,
                    instructions: instructions,
                    tools: tools,
                    isSystem: isSystem,
                    isEnabled: true,
                    user: user
                )
                context.insert(skill)
                try context.save()
                Logger.database.info("SkillCommands.Upsert.execute completed - skill id: \(skill.id)")
                return skill.id
            }
        }
    }
}
