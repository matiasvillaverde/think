import Foundation

/// Options for sorting discovered models
public enum SortOption: String, Sendable, CaseIterable, Codable {
    /// Sort by number of downloads (most downloaded first)
    case downloads

    /// Sort by number of likes (most liked first)
    case likes

    /// Sort by last modified date (most recent first)
    case lastModified = "lastModified"

    /// Sort by trending score (HuggingFace trending algorithm)
    case trending

    /// The API parameter name for this sort option
    public var apiParameter: String {
        switch self {
        case .downloads:
            return "downloads"
        case .likes:
            return "likes"
        case .lastModified:
            return "lastModified"
        case .trending:
            return "trending"
        }
    }

    /// Human-readable display name
    public var displayName: String {
        switch self {
        case .downloads:
            return "Most Downloaded"
        case .likes:
            return "Most Liked"
        case .lastModified:
            return "Recently Updated"
        case .trending:
            return "Trending"
        }
    }
}
