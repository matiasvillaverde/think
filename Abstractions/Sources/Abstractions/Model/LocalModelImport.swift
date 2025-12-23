import Foundation

/// Represents a locally-referenced model import request.
public struct LocalModelImport: Sendable, Equatable {
    public let name: String
    public let backend: SendableModel.Backend
    public let type: SendableModel.ModelType
    public let parameters: UInt64
    public let ramNeeded: UInt64
    public let size: UInt64
    public let locationLocal: String
    public let locationBookmark: Data?

    public init(
        name: String,
        backend: SendableModel.Backend,
        type: SendableModel.ModelType,
        parameters: UInt64,
        ramNeeded: UInt64,
        size: UInt64,
        locationLocal: String,
        locationBookmark: Data?
    ) {
        self.name = name
        self.backend = backend
        self.type = type
        self.parameters = parameters
        self.ramNeeded = ramNeeded
        self.size = size
        self.locationLocal = locationLocal
        self.locationBookmark = locationBookmark
    }
}
