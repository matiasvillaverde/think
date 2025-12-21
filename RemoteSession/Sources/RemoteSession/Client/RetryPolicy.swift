import Foundation

/// Policy for retrying failed requests with exponential backoff.
///
/// This policy implements exponential backoff with jitter, which is
/// the recommended approach for handling rate limits and transient errors.
struct RetryPolicy: Sendable {
    /// Maximum number of retry attempts
    let maxRetries: Int

    /// Base delay for exponential backoff (in seconds)
    let baseDelay: TimeInterval

    /// Maximum delay cap (in seconds)
    let maxDelay: TimeInterval

    /// Jitter factor (0.0 to 1.0) to randomize delays
    let jitterFactor: Double

    /// Default retry policy suitable for most API calls
    static let `default` = Self(
        maxRetries: 3,
        baseDelay: 1.0,
        maxDelay: 30.0,
        jitterFactor: 0.2
    )

    /// Creates a new retry policy.
    ///
    /// - Parameters:
    ///   - maxRetries: Maximum number of retry attempts
    ///   - baseDelay: Base delay for exponential backoff (in seconds)
    ///   - maxDelay: Maximum delay cap (in seconds)
    ///   - jitterFactor: Jitter factor (0.0 to 1.0) to randomize delays
    init(
        maxRetries: Int,
        baseDelay: TimeInterval,
        maxDelay: TimeInterval,
        jitterFactor: Double
    ) {
        self.maxRetries = maxRetries
        self.baseDelay = baseDelay
        self.maxDelay = maxDelay
        self.jitterFactor = min(max(jitterFactor, 0.0), 1.0)
    }

    /// Calculates the delay for a given retry attempt.
    ///
    /// Uses exponential backoff with jitter:
    /// `delay = min(baseDelay * 2^attempt, maxDelay) * (1 ± jitter)`
    ///
    /// - Parameter attempt: The retry attempt number (0-indexed)
    /// - Returns: The delay in seconds before the next retry
    func delay(forAttempt attempt: Int) -> TimeInterval {
        // Calculate exponential delay
        let exponentialDelay = baseDelay * pow(2.0, Double(attempt))

        // Cap at maximum delay
        let cappedDelay = min(exponentialDelay, maxDelay)

        // Add jitter
        let jitterRange = cappedDelay * jitterFactor
        let jitter = Double.random(in: -jitterRange...jitterRange)

        return max(0, cappedDelay + jitter)
    }

    /// Determines if a request should be retried based on the error.
    ///
    /// - Parameters:
    ///   - error: The error that occurred
    ///   - attempt: The current attempt number (0-indexed)
    /// - Returns: True if the request should be retried
    func shouldRetry(error: Error, attempt: Int) -> Bool {
        // Don't retry if we've exhausted attempts
        guard attempt < maxRetries else {
            return false
        }

        // Check for retryable HTTP errors
        if let httpError = error as? HTTPError {
            switch httpError {
            case .statusCode(let code, _):
                return isRetryableStatusCode(code)
            case .timeout:
                return true
            case .invalidResponse, .cancelled:
                return false
            }
        }

        // Check for URL errors
        if let urlError = error as? URLError {
            return isRetryableURLError(urlError)
        }

        // Don't retry unknown errors
        return false
    }

    /// Checks if an HTTP status code is retryable.
    private func isRetryableStatusCode(_ code: Int) -> Bool {
        switch code {
        case 429: // Rate limit
            return true
        case 500, 502, 503, 504: // Server errors
            return true
        default:
            return false
        }
    }

    /// Checks if a URL error is retryable.
    private func isRetryableURLError(_ error: URLError) -> Bool {
        switch error.code {
        case .timedOut,
             .cannotConnectToHost,
             .networkConnectionLost,
             .notConnectedToInternet:
            return true
        default:
            return false
        }
    }

    /// Extracts retry-after duration from HTTP error if available.
    ///
    /// - Parameter error: The error to check
    /// - Returns: The retry-after duration if specified in the response
    func retryAfter(from _: Error) -> Duration? {
        // HTTP errors might include retry-after in headers
        // For now, return nil - this could be enhanced to parse headers
        nil
    }
}
