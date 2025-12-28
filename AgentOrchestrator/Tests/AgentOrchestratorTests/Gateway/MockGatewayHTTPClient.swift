import Foundation

@testable import AgentOrchestrator

internal final actor MockGatewayHTTPClient: GatewayHTTPClient {
    internal var nextData: Data = Data()
    internal var nextStatusCode: Int = 200
    internal private(set) var lastRequest: URLRequest?

    internal func setNextResponse(
        data: Data,
        statusCode: Int = 200
    ) {
        nextData = data
        nextStatusCode = statusCode
    }

    internal func data(for request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        await Task.yield()
        lastRequest = request

        guard let url: URL = request.url else {
            throw URLError(.badURL)
        }

        let response: HTTPURLResponse? = HTTPURLResponse(
            url: url,
            statusCode: nextStatusCode,
            httpVersion: nil,
            headerFields: nil
        )
        guard let httpResponse: HTTPURLResponse = response else {
            throw URLError(.badServerResponse)
        }

        return (nextData, httpResponse)
    }
}
