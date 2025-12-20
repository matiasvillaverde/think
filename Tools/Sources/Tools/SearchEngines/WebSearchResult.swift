import Foundation

/// A data model representing a search result with extracted content
public struct WebSearchResult: Identifiable, Hashable, Sendable {
    /// Unique identifier for the search result
    public let id: UUID = UUID()

    /// The title of the webpage
    public let title: String

    /// A brief snippet or description of the content
    public let snippet: String

    /// The source URL as a string
    public let sourceURL: String

    /// The extracted main content of the webpage, cleaned for LLM consumption
    public let content: String

    /// Date when this result was fetched
    public let fetchDate: Date

    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    public static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.id == rhs.id
    }
}
