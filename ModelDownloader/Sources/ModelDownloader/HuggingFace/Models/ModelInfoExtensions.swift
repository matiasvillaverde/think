import Abstractions
import Foundation

// MARK: - ModelInfo Extensions

extension ModelInfo {
    /// Formatted file size string
    internal var formattedSize: String {
        ByteCountFormatter.string(fromByteCount: totalSize, countStyle: .file)
    }

    /// Check if the model files still exist on disk
    internal var exists: Bool {
        FileManager.default.fileExists(atPath: location.path)
    }

    /// Get the directory containing the model files
    internal var directory: URL {
        location.hasDirectoryPath ? location : location.deletingLastPathComponent()
    }
}
