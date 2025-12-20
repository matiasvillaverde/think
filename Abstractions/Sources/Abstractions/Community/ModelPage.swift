import Foundation

/// Represents a paginated response of discovered models
///
/// The HuggingFace API returns results in pages to handle
/// large result sets efficiently.
public struct ModelPage: Sendable {
    /// The models in this page
    public let models: [DiscoveredModel]

    /// Whether there are more pages available
    public let hasNextPage: Bool

    /// Token for fetching the next page (if available)
    public let nextPageToken: String?

    /// Total number of results (if provided by API)
    public let totalCount: Int?

    /// Initialize a new ModelPage
    /// - Parameters:
    ///   - models: Models in this page
    ///   - hasNextPage: Whether more pages exist
    ///   - nextPageToken: Token for next page
    ///   - totalCount: Total result count
    public init(
        models: [DiscoveredModel],
        hasNextPage: Bool,
        nextPageToken: String? = nil,
        totalCount: Int? = nil
    ) {
        self.models = models
        self.hasNextPage = hasNextPage
        self.nextPageToken = nextPageToken
        self.totalCount = totalCount
    }
}

// MARK: - Convenience

extension ModelPage {
    /// An empty page with no results
    public static var empty: ModelPage {
        ModelPage(models: [], hasNextPage: false)
    }

    /// Whether this page has any models
    public var isEmpty: Bool {
        models.isEmpty
    }

    /// Number of models in this page
    public var count: Int {
        models.count
    }
}
