import Foundation
import SwiftData

@Model
@DebugDescription
public final class CanvasDocument: Identifiable, Equatable {
    // MARK: - Identity

    @Attribute(.unique)
    public private(set) var id: UUID = UUID()

    @Attribute()
    public private(set) var createdAt: Date = Date()

    @Attribute()
    public internal(set) var updatedAt: Date = Date()

    // MARK: - Content

    @Attribute()
    public internal(set) var title: String

    @Attribute()
    public internal(set) var content: String

    // MARK: - Relationships

    @Relationship(deleteRule: .nullify)
    public private(set) var chat: Chat?

    // MARK: - Initializer

    init(
        title: String,
        content: String = "",
        chat: Chat? = nil
    ) {
        self.title = title
        self.content = content
        self.chat = chat
    }
}

#if DEBUG
extension CanvasDocument {
    @MainActor public static let preview: CanvasDocument = {
        CanvasDocument(title: "Canvas", content: "Draft notes")
    }()
}
#endif
