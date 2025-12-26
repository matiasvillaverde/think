import Foundation
import SwiftData
import Abstractions

// MARK: - Chat

@Model
@DebugDescription
public final class Chat: Identifiable, Equatable, ObservableObject {
    // MARK: - Identity

    /// A unique identifier for the entity.
    @Attribute(.unique)
    public private(set) var id: UUID = UUID()

    /// The creation date of the entity.
    @Attribute()
    public private(set) var createdAt: Date = Date()

    /// The creation date of the entity.
    @Attribute()
    public internal(set) var updatedAt: Date = Date()

    @Attribute()
    public private(set) var modifiedAt: Date = Date()

    /// The creation date of the entity.
    @Attribute()
    public private(set) var archivedAt: Date?

    @Attribute()
    public internal(set) var name: String

    @Attribute()
    public private(set) var isFavorite: Bool

    /// Ordered list of fallback model IDs to try if primary model fails to load
    @Attribute()
    public internal(set) var fallbackModelIds: [UUID] = []

    // MARK: - Relationships

    @Relationship(deleteRule: .cascade)
    public private(set) var languageModelConfig: LLMConfiguration

    @Relationship(deleteRule: .cascade)
    public internal(set) var imageModelConfig: DiffusorConfiguration

    @Relationship()
    /// Model owned by the User
    public internal(set) var languageModel: Model

    @Relationship()
    public internal(set) var personality: Personality

    @Relationship()
    /// Model owned by the User
    public internal(set) var imageModel: Model

    @Relationship(deleteRule: .cascade, inverse: \Message.chat)
    public private(set) var messages: [Message] = []

    @Relationship(deleteRule: .nullify)
    public private(set) var user: User?

    // MARK: - Initializer

    init(
        languageModelConfig: LLMConfiguration,
        languageModel: Model,
        imageModelConfig: DiffusorConfiguration,
        imageModel: Model,
        name: String = String(localized: "New Chat", bundle: .module),
        isFavorite: Bool = false,
        user: User,
        messages: [Message] = [],
        personality: Personality
    ) {
        self.languageModelConfig = languageModelConfig
        self.languageModel = languageModel
        self.imageModelConfig = imageModelConfig
        self.imageModel = imageModel
        self.name = name
        self.isFavorite = isFavorite
        self.user = user
        self.messages = messages
        self.personality = personality
    }
}

extension Chat {
    /// This is to create a table on the Vector DB that is associated with this chat.
    public func generateTableName() -> String {
        RagTableName.chatTableName(chatId: id)
    }
}

#if DEBUG
// **MARK: - Previews**

extension Chat {
    @MainActor public static let preview: Chat = {
        // Create simple mock models for preview
        let languageModel = createMockModel(
            name: "Preview Language Model",
            type: .language,
            backend: .mlx,
            state: .downloaded
        )

        let imageModel = createMockModel(
            name: "Preview Image Model",
            type: .diffusion,
            backend: .mlx,
            state: .downloaded
        )

        return Chat(
            languageModelConfig: .preview,
            languageModel: languageModel,
            imageModelConfig: .preview,
            imageModel: imageModel,
            name: "Preview Chat",
            isFavorite: true,
            user: .preview,
            personality: .preview
        )
    }()

    @MainActor private static func createMockModel(
        name: String,
        type: SendableModel.ModelType,
        backend: SendableModel.Backend,
        state: Model.State
    ) -> Model {
        let dto = ModelDTO(
            type: type,
            backend: backend,
            name: name,
            displayName: name,
            displayDescription: "Mock model for preview",
            skills: [],
            parameters: 7_000_000_000,
            ramNeeded: 8.gigabytes,
            size: 4.gigabytes,
            locationHuggingface: name.lowercased().replacingOccurrences(of: " ", with: "-"),
            version: 2
        )

        do {
            let model = try dto.createModel()
            model.state = state
            return model
        } catch {
            // This should never happen in preview code with valid mock data
            fatalError("Failed to create mock model for preview: \(error)")
        }
    }
}
#endif
