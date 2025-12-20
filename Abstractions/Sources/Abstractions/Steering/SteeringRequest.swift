import Foundation

/// A request to steer the current generation
public struct SteeringRequest: Sendable, Equatable {
    /// Unique identifier for this request
    public let id: UUID

    /// The steering mode to apply
    public let mode: SteeringMode

    /// When the request was created
    public let timestamp: Date

    /// Initialize a new steering request
    /// - Parameter mode: The steering mode to apply
    public init(mode: SteeringMode) {
        self.id = UUID()
        self.mode = mode
        self.timestamp = Date()
    }
}
