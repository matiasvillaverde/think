import Foundation
import SwiftData
import Abstractions

/// A skill that teaches agents how to use specific tools effectively
@Model
@DebugDescription
public final class Skill: Identifiable, Equatable {
    // MARK: - Identity

    /// A unique identifier for the skill
    @Attribute(.unique)
    public private(set) var id: UUID = UUID()

    /// The creation date of the skill
    @Attribute()
    public private(set) var createdAt: Date = Date()

    /// The last update date of the skill
    @Attribute()
    public internal(set) var updatedAt: Date = Date()

    // MARK: - Content

    /// Display name of the skill
    @Attribute()
    public internal(set) var name: String

    /// Brief description of what the skill does
    @Attribute()
    public internal(set) var skillDescription: String

    /// Markdown instructions for how to use associated tools
    @Attribute()
    public internal(set) var instructions: String

    /// Tool identifiers this skill relates to (stored as raw strings)
    @Attribute()
    public internal(set) var tools: [String]

    /// Whether this is a system-provided (bundled) skill
    @Attribute()
    public private(set) var isSystem: Bool

    /// Whether the skill is currently enabled
    @Attribute()
    public internal(set) var isEnabled: Bool

    // MARK: - Relationships

    /// The chat this skill is associated with (nil for global skills)
    @Relationship(deleteRule: .nullify)
    public private(set) var chat: Chat?

    /// The user who owns this skill
    @Relationship(deleteRule: .nullify)
    public private(set) var user: User?

    // MARK: - Initializer

    init(
        name: String,
        skillDescription: String,
        instructions: String,
        tools: [String] = [],
        isSystem: Bool = false,
        isEnabled: Bool = true,
        chat: Chat? = nil,
        user: User? = nil
    ) {
        self.name = name
        self.skillDescription = skillDescription
        self.instructions = instructions
        self.tools = tools
        self.isSystem = isSystem
        self.isEnabled = isEnabled
        self.chat = chat
        self.user = user
    }

    // MARK: - Sendable Conversion

    /// Convert to a sendable data representation
    public var toData: SkillData {
        SkillData(
            id: id,
            createdAt: createdAt,
            updatedAt: updatedAt,
            name: name,
            skillDescription: skillDescription,
            instructions: instructions,
            tools: tools,
            isSystem: isSystem,
            isEnabled: isEnabled,
            chatId: chat?.id
        )
    }
}

#if DEBUG

extension Skill {
    @MainActor public static let preview: Skill = {
        Skill(
            name: "Web Research",
            skillDescription: "Research topics using web search and browser tools",
            instructions: """
            ## Instructions
            When researching a topic on the web:
            1. First use `duckduckgo_search` to find relevant sources
            2. Identify the 3 most authoritative results
            3. Use `browser.search` to fetch detailed content from each
            4. Synthesize findings with proper citations
            5. Always mention your sources

            ## Best Practices
            - Prefer official documentation over blogs
            - Cross-reference multiple sources for facts
            - Include publication dates when available
            """,
            tools: ["duckduckgo_search", "browser.search"],
            isSystem: true,
            isEnabled: true
        )
    }()

    @MainActor public static let codingPreview: Skill = {
        Skill(
            name: "Code Assistant",
            skillDescription: "Help with programming tasks using Python execution",
            instructions: """
            ## Instructions
            When helping with code:
            1. Understand the problem clearly before writing code
            2. Use `python_exec` to test and validate solutions
            3. Provide clear explanations alongside code
            4. Handle edge cases and errors gracefully

            ## Best Practices
            - Write clean, readable code
            - Include comments for complex logic
            - Test with multiple inputs
            """,
            tools: ["python_exec"],
            isSystem: true,
            isEnabled: true
        )
    }()
}

#endif
