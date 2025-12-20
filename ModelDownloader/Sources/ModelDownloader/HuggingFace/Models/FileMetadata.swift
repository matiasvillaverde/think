import Foundation

/// Metadata about a file in a HuggingFace repository
internal struct FileMetadata: Sendable, Equatable, Codable {
    internal let filename: String
    internal let size: Int64?
    internal let lastModified: Date?
    internal let etag: String?

    internal init(
        filename: String,
        size: Int64? = nil,
        lastModified: Date? = nil,
        etag: String? = nil
    ) {
        self.filename = filename
        self.size = size
        self.lastModified = lastModified
        self.etag = etag
    }
}
