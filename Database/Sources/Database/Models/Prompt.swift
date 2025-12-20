import Foundation
import SwiftData

@Model
@DebugDescription
public final class Prompt: Identifiable, Equatable {
    // MARK: - Identity

    /// A unique identifier for the entity.
    @Attribute(.unique)
    public private(set) var id: UUID = UUID()

    /// The creation date of the entity.
    @Attribute()
    public private(set) var createdAt: Date = Date()

    // MARK: - Prompt Fields

    /// The title of the prompt.
    @Attribute()
    public private(set) var title: String

    /// A subtitle or short description of the prompt.
    @Attribute()
    public private(set) var subtitle: String

    /// The main text/content of the prompt.
    @Attribute()
    public private(set) var prompt: String

    @Relationship(deleteRule: .nullify)
    public private(set) var personality: Personality?

    // MARK: - Initializer

    init(
        title: String,
        subtitle: String,
        prompt: String,
        personality: Personality
    ) {
        self.title = title
        self.subtitle = subtitle
        self.prompt = prompt
        self.personality = personality
    }
}
