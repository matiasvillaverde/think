import Foundation

/// Sendable data representation of a tool policy
public struct ToolPolicyData: Sendable, Equatable, Identifiable, Codable {
    /// Unique identifier for the policy
    public let id: UUID
    /// When the policy was created
    public let createdAt: Date
    /// When the policy was last updated
    public let updatedAt: Date
    /// The base tool profile
    public let profile: ToolProfile
    /// Additional tools to allow beyond the profile
    public let allowList: [String]
    /// Tools to explicitly deny (overrides profile)
    public let denyList: [String]
    /// Whether this is a global default policy
    public let isGlobal: Bool
    /// Chat ID if this policy is chat-specific (nil for non-chat policies)
    public let chatId: UUID?
    /// Personality ID if this policy is personality-specific
    public let personalityId: UUID?

    /// Initialize a new tool policy data
    public init(
        id: UUID,
        createdAt: Date,
        updatedAt: Date,
        profile: ToolProfile,
        allowList: [String] = [],
        denyList: [String] = [],
        isGlobal: Bool = false,
        chatId: UUID? = nil,
        personalityId: UUID? = nil
    ) {
        self.id = id
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.profile = profile
        self.allowList = allowList
        self.denyList = denyList
        self.isGlobal = isGlobal
        self.chatId = chatId
        self.personalityId = personalityId
    }
}

/// Resolved tool policy after applying all overrides
public struct ResolvedToolPolicy: Sendable, Equatable {
    /// The final set of allowed tools
    public let allowedTools: Set<ToolIdentifier>
    /// The source profile that was used as base
    public let sourceProfile: ToolProfile
    /// Tools that were explicitly added via allow list
    public let addedTools: Set<ToolIdentifier>
    /// Tools that were explicitly removed via deny list
    public let removedTools: Set<ToolIdentifier>

    /// Initialize a new resolved tool policy
    public init(
        allowedTools: Set<ToolIdentifier>,
        sourceProfile: ToolProfile = .full,
        addedTools: Set<ToolIdentifier> = [],
        removedTools: Set<ToolIdentifier> = []
    ) {
        self.allowedTools = allowedTools
        self.sourceProfile = sourceProfile
        self.addedTools = addedTools
        self.removedTools = removedTools
    }

    /// Check if a specific tool is allowed
    public func isToolAllowed(_ tool: ToolIdentifier) -> Bool {
        allowedTools.contains(tool)
    }

    /// Filter a set of requested tools to only those allowed
    public func filterAllowed(_ tools: Set<ToolIdentifier>) -> Set<ToolIdentifier> {
        tools.intersection(allowedTools)
    }

    /// Create a policy that allows all tools
    public static var allowAll: ResolvedToolPolicy {
        ResolvedToolPolicy(
            allowedTools: Set(ToolIdentifier.allCases),
            sourceProfile: .full
        )
    }

    /// Create a policy that allows no tools
    public static var denyAll: ResolvedToolPolicy {
        ResolvedToolPolicy(
            allowedTools: [],
            sourceProfile: .minimal
        )
    }
}
