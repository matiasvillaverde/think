import Foundation

/// Describes a single file to download for a model.
public struct ModelDownloadFile: Sendable, Equatable {
    public let url: URL
    public let relativePath: String
    public let size: Int64

    public init(url: URL, relativePath: String, size: Int64) {
        self.url = url
        self.relativePath = relativePath
        self.size = size
    }
}
