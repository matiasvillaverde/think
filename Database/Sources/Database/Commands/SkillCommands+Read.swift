import Foundation
import SwiftData
import OSLog
import Abstractions

// MARK: - Skill Read Commands
extension SkillCommands {
    /// Reads a single skill by ID
    public struct Read: ReadCommand {
        public typealias Result = Skill

        private let skillId: UUID

        public var requiresUser: Bool { false }
        public var requiresRag: Bool { false }

        /// Initialize a Read command
        /// - Parameter skillId: The ID of the skill to read
        public init(skillId: UUID) {
            self.skillId = skillId
            Logger.database.info("SkillCommands.Read initialized with skillId: \(skillId)")
        }

        public func execute(
            in context: ModelContext,
            userId: PersistentIdentifier?,
            rag: Ragging?
        ) throws -> Skill {
            Logger.database.info("SkillCommands.Read.execute started for skill: \(skillId)")

            let descriptor = FetchDescriptor<Skill>(
                predicate: #Predicate<Skill> { $0.id == skillId }
            )

            let skills = try context.fetch(descriptor)
            guard let skill = skills.first else {
                Logger.database.error("SkillCommands.Read.execute failed: skill not found")
                throw DatabaseError.skillNotFound
            }

            Logger.database.info("SkillCommands.Read.execute completed successfully")
            return skill
        }
    }

    /// Gets all skills for the current user
    public struct GetAll: ReadCommand {
        public typealias Result = [Skill]

        public var requiresUser: Bool { true }
        public var requiresRag: Bool { false }

        public init() {
            Logger.database.info("SkillCommands.GetAll initialized")
        }

        public func execute(
            in context: ModelContext,
            userId: PersistentIdentifier?,
            rag: Ragging?
        ) throws -> [Skill] {
            Logger.database.info("SkillCommands.GetAll.execute started")

            guard let userId else {
                Logger.database.error("SkillCommands.GetAll.execute failed: user not found")
                throw DatabaseError.userNotFound
            }

            let user = try context.getUser(id: userId)

            let descriptor = FetchDescriptor<Skill>(
                sortBy: [SortDescriptor(\.name, order: .forward)]
            )
            let allSkills = try context.fetch(descriptor)
            let userSkills = allSkills.filter { $0.user?.id == user.id }

            Logger.database.info("SkillCommands.GetAll.execute completed - found \(userSkills.count) skills")
            return userSkills
        }
    }

    /// Gets enabled skills for a set of tools
    public struct GetForTools: ReadCommand {
        public typealias Result = [Skill]

        private let toolIdentifiers: Set<String>
        private let chatId: UUID?

        public var requiresUser: Bool { true }
        public var requiresRag: Bool { false }

        /// Initialize a GetForTools command
        /// - Parameters:
        ///   - toolIdentifiers: Tool identifiers to filter by
        ///   - chatId: Optional chat filter
        public init(toolIdentifiers: Set<String>, chatId: UUID? = nil) {
            self.toolIdentifiers = toolIdentifiers
            self.chatId = chatId
            Logger.database.info("SkillCommands.GetForTools initialized with \(toolIdentifiers.count) tools")
        }

        public func execute(
            in context: ModelContext,
            userId: PersistentIdentifier?,
            rag: Ragging?
        ) throws -> [Skill] {
            Logger.database.info("SkillCommands.GetForTools.execute started")

            guard let userId else {
                Logger.database.error("SkillCommands.GetForTools.execute failed: user not found")
                throw DatabaseError.userNotFound
            }

            let user = try context.getUser(id: userId)

            let descriptor = FetchDescriptor<Skill>(
                predicate: #Predicate<Skill> { skill in
                    skill.isEnabled
                },
                sortBy: [SortDescriptor(\.name, order: .forward)]
            )
            let enabledSkills = try context.fetch(descriptor)

            // Filter by user, tools, and optionally chat
            let matchingSkills = enabledSkills.filter { skill in
                skill.user?.id == user.id &&
                skill.tools.contains { toolIdentifiers.contains($0) } &&
                (chatId == nil || skill.chat == nil || skill.chat?.id == chatId)
            }

            Logger.database.info(
                "SkillCommands.GetForTools.execute completed - found \(matchingSkills.count) skills"
            )
            return matchingSkills
        }
    }

    /// Gets the complete skill context for prompt injection
    public struct GetSkillContext: ReadCommand {
        public typealias Result = SkillContext

        private let toolIdentifiers: Set<String>
        private let chatId: UUID?

        public var requiresUser: Bool { true }
        public var requiresRag: Bool { false }

        /// Initialize a GetSkillContext command
        /// - Parameters:
        ///   - toolIdentifiers: Tool identifiers to filter by
        ///   - chatId: Optional chat filter
        public init(toolIdentifiers: Set<String>, chatId: UUID? = nil) {
            self.toolIdentifiers = toolIdentifiers
            self.chatId = chatId
            Logger.database.info("SkillCommands.GetSkillContext initialized")
        }

        public func execute(
            in context: ModelContext,
            userId: PersistentIdentifier?,
            rag: Ragging?
        ) throws -> SkillContext {
            Logger.database.info("SkillCommands.GetSkillContext.execute started")

            guard let userId else {
                Logger.database.error("SkillCommands.GetSkillContext.execute failed: user not found")
                throw DatabaseError.userNotFound
            }

            // Get skills matching the tools
            let skills = try GetForTools(toolIdentifiers: toolIdentifiers, chatId: chatId)
                .execute(in: context, userId: userId, rag: rag)

            let skillContext = SkillContext(
                activeSkills: skills.map(\.toData)
            )

            Logger.database.info(
                "SkillCommands.GetSkillContext.execute completed - \(skills.count) active skills"
            )
            return skillContext
        }
    }
}
