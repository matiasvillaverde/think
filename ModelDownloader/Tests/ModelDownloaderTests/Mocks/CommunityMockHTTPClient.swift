import Foundation
@testable import ModelDownloader

/// Mock HTTP client for community testing
final class CommunityMockHTTPClient: HTTPClientProtocol, @unchecked Sendable {
    var responses: [String: HTTPClientResponse] = [:]
    var onRequest: ((URL, [String: String]) -> Void)?
    var error: Error?

    func get(url: URL, headers: [String: String]) throws -> HTTPClientResponse {
        onRequest?(url, headers)

        if let error {
            throw error
        }

        // Extract path for matching
        let path: String = url.path

        // Check for exact matches first
        if let response = responses[path] {
            return response
        }

        // Check for pattern matches in the full URL (including query params)
        let urlString: String = url.absoluteString
        for (pattern, response) in responses where urlString.contains(pattern) {
            return response
        }

        // Check for pattern matches in path only
        for (pattern, response) in responses where path.contains(pattern) {
            return response
        }

        // Default 404
        return HTTPClientResponse(data: Data(), statusCode: 404, headers: [:])
    }

    deinit {
        // No cleanup required
    }

    func head(url: URL, headers: [String: String]) throws -> HTTPClientResponse {
        if let error {
            throw error
        }

        // For HEAD requests, return same as GET but without data
        let getResponse: HTTPClientResponse = try get(url: url, headers: headers)
        return HTTPClientResponse(
            data: Data(), // HEAD requests don't have body
            statusCode: getResponse.statusCode,
            headers: getResponse.headers
        )
    }
}
