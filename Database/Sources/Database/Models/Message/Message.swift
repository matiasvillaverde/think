import SwiftData
import SwiftUI

@Model
@DebugDescription
public final class Message: Identifiable, Equatable, ObservableObject {
    // MARK: - Identity

    /// A unique identifier for the entity.
    @Attribute()
    public private(set) var id: UUID = UUID()

    /// The creation date of the entity.
    @Attribute()
    public private(set) var createdAt: Date = Date()

    // MARK: - Metadata

    @Attribute()
    public internal(set) var userInput: String?

    /// Version counter to trigger SwiftData observation
    @Attribute()
    public internal(set) var version: Int = 0

    /// The count of tokens of the prompt + response. Used to calculate the context
    @Attribute()
    public private(set) var tokenCount: Int?

    // MARK: - Relationships

    // `.nullify` ensures that when a Chat is deleted, this property is set to `nil` instead of creating conflicts
    @Relationship(deleteRule: .nullify)
    public private(set) var chat: Chat?

    @Relationship(deleteRule: .cascade)
    public private(set) var languageModelConfiguration: LLMConfiguration

    @Relationship()
    /// Model owned by the User
    public private(set) var languageModel: Model

    @Relationship()
    /// Model owned by the User
    public private(set) var imageModel: Model

    @Relationship(deleteRule: .cascade, inverse: \Metrics.message)
    public internal(set) var metrics: Metrics?

    // MARK: - Optional attachments to increase

    @Relationship(deleteRule: .cascade)
    public var userImage: ImageAttachment?

    @Relationship(deleteRule: .cascade)
    public var responseImage: ImageAttachment?

    @Relationship(deleteRule: .cascade, inverse: \FileAttachment.message)
    public internal(set) var file: [FileAttachment]?

    // MARK: - Channel Support
    
    /// Channel entities (relationship-based)
    @Relationship(deleteRule: .cascade, inverse: \Channel.message)
    public internal(set) var channels: [Channel]?

    // MARK: - Initializers

    init(
        userInput: String? = nil,
        chat: Chat,
        languageModelConfiguration: LLMConfiguration,
        languageModel: Model,
        imageModel: Model,
        metrics: Metrics? = nil,
        userImage: ImageAttachment? = nil,
        responseImage: ImageAttachment? = nil,
        file: [FileAttachment]? = nil
    ) {
        self.userInput = userInput
        self.chat = chat
        self.languageModelConfiguration = languageModelConfiguration
        self.languageModel = languageModel
        self.imageModel = imageModel
        self.metrics = metrics
        self.userImage = userImage
        self.responseImage = responseImage
        self.file = file
        // Channels are now created separately via Channel entities
    }
    
    // MARK: - Channel Entity Helpers
    
    /// Returns channels sorted by order
    public var sortedChannels: [Channel] {
        guard let channels = channels else { return [] }
        return channels.sorted { $0.order < $1.order }
    }
}
