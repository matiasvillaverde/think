import Foundation
import SwiftData

@Model
@DebugDescription
public final class User: Identifiable, Equatable {
    // MARK: - Identity

    /// A unique identifier for the entity.
    @Attribute(.unique)
    public private(set) var id: UUID = UUID()

    /// The creation date of the entity.
    @Attribute()
    public private(set) var createdAt: Date = Date()

    // MARK: - Metadata

    /// The user's name.
    @Attribute()
    public private(set) var name: String?

    // MARK: - Relationships

    /// The user's optional profile picture attachment.
    @Relationship(deleteRule: .cascade)
    public private(set) var profilePicture: ImageAttachment?

    /// A list of custom prompts the user has saved.
    @Relationship(deleteRule: .cascade)
    public private(set) var prompts: [Prompt]

    @Relationship(deleteRule: .cascade, inverse: \Personality.user)
    public private(set) var customPersonalities: [Personality] = []

    /// All chats owned by the user.
    @Relationship(deleteRule: .cascade, inverse: \Chat.user)
    public private(set) var chats: [Chat]

    /// Collection of configurations of the LLMs that act as personalities.
    @Relationship(deleteRule: .cascade)
    public private(set) var agents: [LLMConfiguration]

    @Relationship(deleteRule: .cascade)
    public internal(set) var models: [Model]

    /// User settings (singleton).
    @Relationship(deleteRule: .cascade)
    public internal(set) var settings: AppSettings?

    // MARK: - Initializer

    init(
        name: String? = nil,
        profilePicture: ImageAttachment? = nil,
        prompts: [Prompt] = [],
        chats: [Chat] = [],
        agents: [LLMConfiguration] = [],
        models: [Model] = [],
        settings: AppSettings? = nil
    ) {
        self.name = name
        self.profilePicture = profilePicture
        self.prompts = prompts
        self.chats = chats
        self.agents = agents
        self.models = Array(models)
        self.settings = settings
    }
}

#if DEBUG

extension User {
    @MainActor public static let preview: User = {
        let user = User(
            name: "Matias",
            profilePicture: nil,
            prompts: [],
            chats: [],
            agents: [],
            models: []
        )
        return user
    }()
}

#endif
