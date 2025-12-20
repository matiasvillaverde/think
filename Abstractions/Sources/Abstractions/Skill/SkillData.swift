import Foundation

/// Sendable data representation of a skill
public struct SkillData: Sendable, Equatable, Identifiable, Codable {
    /// Unique identifier for the skill
    public let id: UUID
    /// When the skill was created
    public let createdAt: Date
    /// When the skill was last updated
    public let updatedAt: Date
    /// Display name of the skill
    public let name: String
    /// Brief description of what the skill does
    public let skillDescription: String
    /// Markdown instructions for how to use associated tools
    public let instructions: String
    /// Tool identifiers this skill relates to
    public let tools: [String]
    /// Whether this is a system-provided (bundled) skill
    public let isSystem: Bool
    /// Whether the skill is currently enabled
    public let isEnabled: Bool
    /// Chat ID if this skill is chat-specific (nil for global)
    public let chatId: UUID?

    /// Initialize a new skill data
    public init(
        id: UUID,
        createdAt: Date,
        updatedAt: Date,
        name: String,
        skillDescription: String,
        instructions: String,
        tools: [String] = [],
        isSystem: Bool = false,
        isEnabled: Bool = true,
        chatId: UUID? = nil
    ) {
        self.id = id
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.name = name
        self.skillDescription = skillDescription
        self.instructions = instructions
        self.tools = tools
        self.isSystem = isSystem
        self.isEnabled = isEnabled
        self.chatId = chatId
    }
}

/// Container for skills to be injected into prompts
public struct SkillContext: Sendable, Equatable {
    /// Active skills applicable to the current context
    public let activeSkills: [SkillData]

    /// Initialize a new skill context
    public init(activeSkills: [SkillData] = []) {
        self.activeSkills = activeSkills
    }

    /// Check if there are any skills to inject
    public var isEmpty: Bool {
        activeSkills.isEmpty
    }

    /// Filter skills by tool identifiers
    /// - Parameter toolIdentifiers: Tool identifiers to filter by
    /// - Returns: Skills that have at least one matching tool
    public func skills(for toolIdentifiers: Set<String>) -> [SkillData] {
        activeSkills.filter { skill in
            skill.isEnabled && skill.tools.contains { toolIdentifiers.contains($0) }
        }
    }
}
