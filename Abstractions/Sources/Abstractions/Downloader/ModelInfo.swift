import Foundation

/// Information about a downloaded model
///
/// This struct tracks downloaded model information using the SendableModel's ID
/// as the single source of truth for model identity.
public struct ModelInfo: Sendable, Codable, Equatable, Identifiable {
    /// The SendableModel's unique identifier - single source of truth for model identity
    public let id: UUID

    /// Human-readable name of the model
    public let name: String

    /// Backend of the model (MLX, GGUF, CoreML)
    public let backend: SendableModel.Backend

    /// Local file system location of the model
    public let location: URL

    /// Total size in bytes of all model files
    public let totalSize: Int64

    /// Date when the model was downloaded
    public let downloadDate: Date

    /// Optional metadata about the model
    public let metadata: [String: String]

    /// Create a new ModelInfo
    /// - Parameters:
    ///   - id: The SendableModel's UUID (single source of truth)
    ///   - name: Human-readable name
    ///   - backend: Model backend
    ///   - location: Local file location
    ///   - totalSize: Total size in bytes
    ///   - downloadDate: Download timestamp
    ///   - metadata: Optional additional metadata
    public init(
        id: UUID,
        name: String,
        backend: SendableModel.Backend,
        location: URL,
        totalSize: Int64,
        downloadDate: Date,
        metadata: [String: String] = [:]
    ) {
        self.id = id
        self.name = name
        self.backend = backend
        self.location = location
        self.totalSize = totalSize
        self.downloadDate = downloadDate
        self.metadata = metadata
    }
}
