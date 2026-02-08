import Foundation

internal struct OpenClawConnectAttempt: Sendable, Equatable {
    internal let instanceId: UUID
    internal let url: URL
    internal let role: String
    internal let scopes: [String]
    internal let authToken: String?
    internal let timeoutSeconds: TimeInterval
}
