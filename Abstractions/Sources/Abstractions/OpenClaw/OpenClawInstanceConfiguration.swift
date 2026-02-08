import Foundation

/// Full configuration needed to attempt a gateway connection.
public struct OpenClawInstanceConfiguration: Sendable, Equatable, Codable {
    public let id: UUID
    public let name: String
    public let urlString: String
    public let authToken: String?

    public init(
        id: UUID,
        name: String,
        urlString: String,
        authToken: String?
    ) {
        self.id = id
        self.name = name
        self.urlString = urlString
        self.authToken = authToken
    }
}
