import Foundation

/// Sendable data representation of a memory entry
public struct MemoryData: Sendable, Equatable, Identifiable, Codable {
    /// Unique identifier for the memory
    public let id: UUID
    /// When the memory was created
    public let createdAt: Date
    /// When the memory was last updated
    public let updatedAt: Date
    /// The type of memory (soul, longTerm, daily)
    public let type: MemoryType
    /// The content of the memory
    public let content: String
    /// For daily logs, the date this entry refers to (YYYY-MM-DD)
    public let date: Date?
    /// Keywords for semantic search
    public let keywords: [String]
    /// The chat this memory is associated with (nil for global memories)
    public let chatId: UUID?

    /// Initialize a new memory data
    public init(
        id: UUID,
        createdAt: Date,
        updatedAt: Date,
        type: MemoryType,
        content: String,
        date: Date? = nil,
        keywords: [String] = [],
        chatId: UUID? = nil
    ) {
        self.id = id
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.type = type
        self.content = content
        self.date = date
        self.keywords = keywords
        self.chatId = chatId
    }
}

/// Container for memory context to be injected into prompts
public struct MemoryContext: Sendable, Equatable {
    /// The soul/persona memory (if any)
    public let soul: MemoryData?
    /// Long-term memories
    public let longTermMemories: [MemoryData]
    /// Recent daily logs (typically last 2 days)
    public let recentDailyLogs: [MemoryData]

    /// Initialize a new memory context
    public init(
        soul: MemoryData? = nil,
        longTermMemories: [MemoryData] = [],
        recentDailyLogs: [MemoryData] = []
    ) {
        self.soul = soul
        self.longTermMemories = longTermMemories
        self.recentDailyLogs = recentDailyLogs
    }

    /// Check if there is any memory content to inject
    public var isEmpty: Bool {
        soul == nil && longTermMemories.isEmpty && recentDailyLogs.isEmpty
    }
}
