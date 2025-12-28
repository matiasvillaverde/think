import Foundation

public struct URLSessionGatewayHTTPClient: GatewayHTTPClient {
    private let session: URLSession

    public init(session: URLSession = .shared) {
        self.session = session
    }

    public func data(for request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        let response: (Data, URLResponse) = try await session.data(for: request)
        let data: Data = response.0
        let urlResponse: URLResponse = response.1
        guard let httpResponse: HTTPURLResponse = urlResponse as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
        return (data, httpResponse)
    }
}
