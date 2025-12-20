import Foundation

/// Information about a file to be downloaded in background
public struct BackgroundFileDownload: Sendable, Codable {
    /// Source URL
    public let url: URL

    /// Local destination path
    public let localPath: URL

    /// Expected file size
    public let size: Int64

    /// Relative path for progress display
    public let relativePath: String

    public init(url: URL, localPath: URL, size: Int64, relativePath: String) {
        self.url = url
        self.localPath = localPath
        self.size = size
        self.relativePath = relativePath
    }
}
