import Foundation

public struct RemoteGatewayConfiguration: Sendable, Equatable {
    public let baseURL: URL
    public let authToken: String?
    public let additionalHeaders: [String: String]

    public init(
        baseURL: URL,
        authToken: String? = nil,
        additionalHeaders: [String: String] = [:]
    ) {
        self.baseURL = baseURL
        self.authToken = authToken
        self.additionalHeaders = additionalHeaders
    }
}
