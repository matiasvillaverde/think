import Foundation

/// Protocol for HTTP streaming clients.
///
/// This protocol abstracts URLSession for testability, allowing
/// mock implementations to be injected for unit testing.
protocol HTTPClientProtocol: Sendable {
    /// Streams data from a URL request.
    ///
    /// - Parameter request: The URL request to execute
    /// - Returns: An async stream of data chunks
    func stream(_ request: URLRequest) -> AsyncThrowingStream<Data, Error>
}

/// HTTP client for streaming responses using URLSession.
///
/// This client is designed for Server-Sent Events (SSE) streaming,
/// commonly used by LLM API providers for real-time text generation.
final class HTTPClient: HTTPClientProtocol, @unchecked Sendable {
    /// Shared instance for convenience
    static let shared = HTTPClient()

    /// The underlying URL session
    private let session: URLSession

    /// Default timeout for requests (2 minutes)
    private let defaultTimeout: TimeInterval = 120

    /// Creates a new HTTP client.
    ///
    /// - Parameter session: The URL session to use (defaults to shared)
    init(session: URLSession = .shared) {
        self.session = session
    }

    /// Streams data from a URL request.
    ///
    /// This method uses URLSession's async bytes API to stream
    /// response data as it arrives.
    ///
    /// - Parameter request: The URL request to execute
    /// - Returns: An async stream of data chunks
    func stream(_ request: URLRequest) -> AsyncThrowingStream<Data, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    var mutableRequest = request
                    mutableRequest.timeoutInterval = defaultTimeout

                    let (bytes, response) = try await session.bytes(for: mutableRequest)

                    guard let httpResponse = response as? HTTPURLResponse else {
                        continuation.finish(
                            throwing: HTTPError.invalidResponse
                        )
                        return
                    }

                    // Check for error status codes before streaming
                    if httpResponse.statusCode >= 400 {
                        // Try to read the error body
                        var errorData = Data()
                        for try await byte in bytes {
                            errorData.append(byte)
                        }
                        continuation.finish(
                            throwing: HTTPError.statusCode(
                                httpResponse.statusCode,
                                errorData
                            )
                        )
                        return
                    }

                    // Stream the response
                    var buffer = Data()
                    for try await byte in bytes {
                        buffer.append(byte)
                        // Yield when we have a complete line
                        if byte == UInt8(ascii: "\n") {
                            continuation.yield(buffer)
                            buffer = Data()
                        }
                    }

                    // Yield any remaining data
                    if !buffer.isEmpty {
                        continuation.yield(buffer)
                    }

                    continuation.finish()
                } catch {
                    if Task.isCancelled {
                        continuation.finish(throwing: CancellationError())
                    } else {
                        continuation.finish(throwing: error)
                    }
                }
            }

            continuation.onTermination = { @Sendable _ in
                task.cancel()
            }
        }
    }
}

/// HTTP-specific errors.
enum HTTPError: Error, Sendable {
    /// Response was not an HTTP response
    case invalidResponse

    /// Server returned an error status code
    case statusCode(Int, Data)

    /// Request timed out
    case timeout

    /// Request was cancelled
    case cancelled
}
