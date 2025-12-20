import Foundation
import SwiftData
import Abstractions

/// A persistent memory entry that stores facts, persona definitions, or daily logs
@Model
@DebugDescription
public final class Memory: Identifiable, Equatable {
    // MARK: - Identity

    /// A unique identifier for the memory
    @Attribute(.unique)
    public private(set) var id: UUID = UUID()

    /// The creation date of the memory
    @Attribute()
    public private(set) var createdAt: Date = Date()

    /// The last update date of the memory
    @Attribute()
    public internal(set) var updatedAt: Date = Date()

    // MARK: - Content

    /// The raw string value of the memory type for SwiftData predicate compatibility
    @Attribute()
    public private(set) var typeRaw: String

    /// The type of memory (soul, longTerm, daily)
    public var type: MemoryType {
        MemoryType(rawValue: typeRaw) ?? .longTerm
    }

    /// The content of the memory
    @Attribute()
    public internal(set) var content: String

    /// For daily logs, the date this entry refers to (YYYY-MM-DD)
    @Attribute()
    public private(set) var date: Date?

    /// Keywords for semantic search and filtering
    @Attribute()
    public internal(set) var keywords: [String]

    // MARK: - Relationships

    /// The chat this memory is associated with (nil for global memories)
    @Relationship(deleteRule: .nullify)
    public private(set) var chat: Chat?

    /// The user who owns this memory
    @Relationship(deleteRule: .nullify)
    public private(set) var user: User?

    // MARK: - Initializer

    init(
        type: MemoryType,
        content: String,
        date: Date? = nil,
        keywords: [String] = [],
        chat: Chat? = nil,
        user: User? = nil
    ) {
        self.typeRaw = type.rawValue
        self.content = content
        self.date = date
        self.keywords = keywords
        self.chat = chat
        self.user = user
    }

    // MARK: - Sendable Conversion

    /// Convert to a sendable data representation
    public var toData: MemoryData {
        MemoryData(
            id: id,
            createdAt: createdAt,
            updatedAt: updatedAt,
            type: type,
            content: content,
            date: date,
            keywords: keywords,
            chatId: chat?.id
        )
    }
}

#if DEBUG

extension Memory {
    @MainActor public static let preview: Memory = {
        let memory = Memory(
            type: .longTerm,
            content: "User prefers dark mode and concise responses.",
            keywords: ["preferences", "dark mode", "responses"]
        )
        return memory
    }()

    @MainActor public static let soulPreview: Memory = {
        let memory = Memory(
            type: .soul,
            content: """
            You are a helpful assistant named Think.
            You are friendly, knowledgeable, and always strive to be accurate.
            You prefer to explain things clearly and concisely.
            """,
            keywords: ["persona", "identity", "behavior"]
        )
        return memory
    }()

    @MainActor public static let dailyPreview: Memory = {
        let memory = Memory(
            type: .daily,
            content: "User worked on the Memory System implementation today.",
            date: Date(),
            keywords: ["daily", "memory system"]
        )
        return memory
    }()
}

#endif
