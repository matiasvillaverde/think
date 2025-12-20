import Foundation

/// Represents a file within a HuggingFace model repository
///
/// This lightweight structure contains basic file information
/// discovered through the HuggingFace API.
public struct ModelFile: Sendable, Codable, Equatable, Hashable {
    /// The file path relative to the repository root
    public let path: String

    /// The file size in bytes (nil if size information unavailable)
    public let size: Int64?

    /// The file's SHA hash (if available)
    public let sha: String?

    /// Initialize a new ModelFile
    /// - Parameters:
    ///   - path: File path relative to repository root
    ///   - size: File size in bytes (optional)
    ///   - sha: File SHA hash (optional)
    public init(path: String, size: Int64? = nil, sha: String? = nil) {
        self.path = path
        self.size = size
        self.sha = sha
    }
}

// MARK: - Computed Properties

extension ModelFile {
    /// The filename component of the path
    public var filename: String {
        URL(fileURLWithPath: path).lastPathComponent
    }

    /// The file extension (lowercase)
    public var fileExtension: String {
        URL(fileURLWithPath: path).pathExtension.lowercased()
    }

    /// Formatted file size string
    public var formattedSize: String {
        guard let size else {
            return "Unknown size"
        }
        return ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
    }

    /// Whether this file is likely a model weight file
    public var isModelFile: Bool {
        let modelExtensions = ["safetensors", "gguf", "bin", "mlmodel", "mlpackage", "pt", "h5"]
        return modelExtensions.contains(fileExtension)
    }

    /// Whether this file is a configuration file
    public var isConfigFile: Bool {
        let configExtensions = ["json", "yaml", "yml", "plist"]
        return configExtensions.contains(fileExtension)
    }
}
