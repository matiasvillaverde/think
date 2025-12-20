import Foundation

/// Handle for tracking and controlling background downloads
public struct BackgroundDownloadHandle: Sendable {
    /// Unique identifier for this download
    public let id: UUID

    /// HuggingFace model identifier
    public let modelId: String

    /// Model backend being downloaded
    public let backend: SendableModel.Backend

    /// Session identifier for the background download
    public let sessionIdentifier: String

    public init(id: UUID, modelId: String, backend: SendableModel.Backend, sessionIdentifier: String) {
        self.id = id
        self.modelId = modelId
        self.backend = backend
        self.sessionIdentifier = sessionIdentifier
    }
}
