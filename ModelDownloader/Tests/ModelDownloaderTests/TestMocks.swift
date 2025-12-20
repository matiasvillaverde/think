import Abstractions
import Foundation
@testable import ModelDownloader
import Testing

// MARK: - Mock Streaming Downloader

internal actor MockStreamingDownloader: StreamingDownloaderProtocol {
    func download(
        from _: URL,
        to destination: URL,
        headers _: [String: String],
        progressHandler: @Sendable (Double) -> Void
    ) -> URL {
        progressHandler(1.0)
        return destination
    }

    func downloadResume(
        from url: URL,
        to destination: URL,
        headers: [String: String],
        progressHandler: @Sendable (Double) -> Void
    ) async throws -> URL {
        await Task.yield()
        try Task.checkCancellation()
        return download(
            from: url,
            to: destination,
            headers: headers,
            progressHandler: progressHandler
        )
    }

    func cancel(url _: URL) {}
    func cancelAll() {}
    func pause(url _: URL) {}
    func pauseAll() {}
    func resume(url _: URL) {}
    func resumeAll() {}
}

// MARK: - Mock HTTP Client

internal struct MockHTTPClient: HTTPClientProtocol {
    func get(url _: URL, headers _: [String: String]) -> HTTPClientResponse {
        // Return a mock file list for HuggingFace API
        let mockFiles: String = """
        [
            {
                "path": "config.json",
                "size": 1024,
                "lfs": null
            },
            {
                "path": "model.safetensors",
                "size": 100000,
                "lfs": {
                    "size": 100000,
                    "sha256": "abc123",
                    "pointer_size": 100
                }
            }
        ]
        """
        let data: Data = mockFiles.data(using: .utf8)!
        return HTTPClientResponse(data: data, statusCode: 200)
    }

    func head(url _: URL, headers _: [String: String]) -> HTTPClientResponse {
        HTTPClientResponse(data: Data(), statusCode: 200)
    }
}

// MARK: - Failing Mock HTTP Client

internal struct FailingMockHTTPClient: HTTPClientProtocol {
    func get(url _: URL, headers _: [String: String]) throws -> HTTPClientResponse {
        throw URLError(.networkConnectionLost)
    }

    func head(url _: URL, headers _: [String: String]) throws -> HTTPClientResponse {
        throw URLError(.networkConnectionLost)
    }
}

// MARK: - Configurable Mock HTTP Client

internal final class ConfigurableMockHTTPClient: HTTPClientProtocol, @unchecked Sendable {
    var mockResponses: [String: HTTPClientResponse] = [:]
    var capturedHeaders: [String: [String: String]] = [:]

    func get(url: URL, headers: [String: String]) throws -> HTTPClientResponse {
        capturedHeaders[url.absoluteString] = headers
        guard let response: HTTPClientResponse = mockResponses[url.absoluteString] else {
            throw HuggingFaceError.invalidResponse
        }
        return response
    }

    func head(url: URL, headers: [String: String]) throws -> HTTPClientResponse {
        capturedHeaders[url.absoluteString] = headers
        guard let response: HTTPClientResponse = mockResponses[url.absoluteString] else {
            throw HuggingFaceError.invalidResponse
        }
        return response
    }

    func verifyAuthorizationHeader(for url: String) -> String? {
        capturedHeaders[url]?["Authorization"] as String?
    }

    deinit {
        // No cleanup required
    }
}
