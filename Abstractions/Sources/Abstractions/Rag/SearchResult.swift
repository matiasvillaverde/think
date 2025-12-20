import Foundation

public struct SearchResult: Sendable, Identifiable, Equatable {
    public let id: UUID

    public let text: String
    public let keywords: String
    public let score: Double
    public let rowId: UInt

    public init(id: UUID, text: String, keywords: String, score: Double, rowId: UInt) {
        self.id = id
        self.text = text
        self.keywords = keywords
        self.score = score
        self.rowId = rowId
    }

    public var previousChunkId: UInt? { rowId > 0 ? rowId - 1 : nil }
    public var nextChunkId: UInt? { rowId + 1 }
}
