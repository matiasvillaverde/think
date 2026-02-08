import Foundation

/// A persisted OpenClaw gateway instance configuration (as seen by the UI).
public struct OpenClawInstanceRecord: Sendable, Equatable, Identifiable, Codable {
    public let id: UUID
    public let name: String
    public let urlString: String
    public let hasAuthToken: Bool
    public let isActive: Bool
    public let createdAt: Date
    public let updatedAt: Date

    public init(
        id: UUID,
        name: String,
        urlString: String,
        hasAuthToken: Bool,
        isActive: Bool,
        createdAt: Date,
        updatedAt: Date
    ) {
        self.id = id
        self.name = name
        self.urlString = urlString
        self.hasAuthToken = hasAuthToken
        self.isActive = isActive
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}
