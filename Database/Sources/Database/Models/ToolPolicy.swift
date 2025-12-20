import Foundation
import SwiftData
import Abstractions

/// A policy that controls which tools are available in a context
@Model
@DebugDescription
public final class ToolPolicy: Identifiable, Equatable {
    // MARK: - Identity

    /// A unique identifier for the policy
    @Attribute(.unique)
    public private(set) var id: UUID = UUID()

    /// The creation date of the policy
    @Attribute()
    public private(set) var createdAt: Date = Date()

    /// The last update date of the policy
    @Attribute()
    public internal(set) var updatedAt: Date = Date()

    // MARK: - Content

    /// The raw string value of the profile for SwiftData predicate compatibility
    @Attribute()
    public private(set) var profileRaw: String

    /// The base tool profile
    public var profile: ToolProfile {
        ToolProfile(rawValue: profileRaw) ?? .full
    }

    /// Additional tools to allow beyond the profile (stored as raw strings)
    @Attribute()
    public internal(set) var allowList: [String]

    /// Tools to explicitly deny (overrides profile, stored as raw strings)
    @Attribute()
    public internal(set) var denyList: [String]

    /// Whether this is a global default policy
    @Attribute()
    public private(set) var isGlobal: Bool

    // MARK: - Relationships

    /// The chat this policy is associated with (highest priority)
    @Relationship(deleteRule: .nullify)
    public private(set) var chat: Chat?

    /// The personality this policy is associated with
    @Relationship(deleteRule: .nullify)
    public private(set) var personality: Personality?

    /// The user who owns this policy
    @Relationship(deleteRule: .nullify)
    public private(set) var user: User?

    // MARK: - Initializer

    init(
        profile: ToolProfile,
        allowList: [String] = [],
        denyList: [String] = [],
        isGlobal: Bool = false,
        chat: Chat? = nil,
        personality: Personality? = nil,
        user: User? = nil
    ) {
        self.profileRaw = profile.rawValue
        self.allowList = allowList
        self.denyList = denyList
        self.isGlobal = isGlobal
        self.chat = chat
        self.personality = personality
        self.user = user
    }

    // MARK: - Sendable Conversion

    /// Convert to a sendable data representation
    public var toData: ToolPolicyData {
        ToolPolicyData(
            id: id,
            createdAt: createdAt,
            updatedAt: updatedAt,
            profile: profile,
            allowList: allowList,
            denyList: denyList,
            isGlobal: isGlobal,
            chatId: chat?.id,
            personalityId: personality?.id
        )
    }

    // MARK: - Profile Update

    /// Update the profile
    internal func setProfile(_ newProfile: ToolProfile) {
        self.profileRaw = newProfile.rawValue
        self.updatedAt = Date()
    }
}

#if DEBUG

extension ToolPolicy {
    @MainActor public static let preview: ToolPolicy = {
        ToolPolicy(
            profile: .research,
            allowList: [],
            denyList: [],
            isGlobal: false
        )
    }()

    @MainActor public static let minimalPreview: ToolPolicy = {
        ToolPolicy(
            profile: .minimal,
            isGlobal: false
        )
    }()

    @MainActor public static let fullPreview: ToolPolicy = {
        ToolPolicy(
            profile: .full,
            isGlobal: true
        )
    }()
}

#endif
