import Foundation

/// Sort direction for model search operations
///
/// Specifies whether search results should be sorted in ascending or descending order.
/// Used in conjunction with SortOption to define complete sorting behavior for
/// discovered model queries.
///
/// ## Usage
/// ```swift
/// // Sort by downloads in descending order (most downloaded first)
/// let sortOption = SortOption.downloads
/// let sortDirection = SortDirection.descending
/// 
/// // Sort by last modified in ascending order (oldest first)
/// let sortOption = SortOption.lastModified
/// let sortDirection = SortDirection.ascending
/// ```
public enum SortDirection: String, Sendable, Codable, CaseIterable {
    /// Sort in ascending order (lowest to highest, oldest to newest)
    case ascending = "asc"

    /// Sort in descending order (highest to lowest, newest to oldest)
    case descending = "desc"
}
