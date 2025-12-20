import Foundation

/// Protocol for implementing retry policies
internal protocol RetryPolicy: Sendable {
    /// Maximum number of retry attempts
    var maxRetries: Int { get }

    /// Calculate delay before retry attempt
    /// - Parameter attempt: The retry attempt number (1-based)
    /// - Returns: Delay in seconds before retrying
    func delayForRetry(attempt: Int) async -> TimeInterval

    /// Determine if an error is retryable
    /// - Parameter error: The error that occurred
    /// - Returns: true if the operation should be retried
    func shouldRetry(error: Error) async -> Bool
}

/// Exponential backoff retry policy with jitter
internal actor ExponentialBackoffRetryPolicy: RetryPolicy {
    internal let maxRetries: Int
    private let baseDelay: TimeInterval
    private let maxDelay: TimeInterval
    private let jitter: Double

    /// Initialize exponential backoff retry policy
    /// - Parameters:
    ///   - maxRetries: Maximum number of retry attempts
    ///   - baseDelay: Base delay in seconds (multiplied by 2^attempt)
    ///   - maxDelay: Maximum delay cap in seconds
    ///   - jitter: Random jitter factor (0.0 to 1.0)
    internal init(
        maxRetries: Int = 3,
        baseDelay: TimeInterval = 1.0,
        maxDelay: TimeInterval = 60.0,
        jitter: Double = 0.1
    ) {
        self.maxRetries = maxRetries
        self.baseDelay = baseDelay
        self.maxDelay = maxDelay
        self.jitter = min(1.0, max(0.0, jitter))
    }

    internal func delayForRetry(attempt: Int) -> TimeInterval {
        // Calculate exponential delay
        let exponentialDelay: TimeInterval = baseDelay * pow(2.0, Double(attempt - 1))
        let cappedDelay: TimeInterval = min(exponentialDelay, maxDelay)

        // Add jitter
        if jitter > 0 {
            let jitterRange: TimeInterval = cappedDelay * jitter
            let randomJitter: Double = Double.random(in: -jitterRange...jitterRange)
            return max(0, cappedDelay + randomJitter)
        }

        return cappedDelay
    }

    internal func shouldRetry(error: Error) -> Bool {
        // Retry on network errors
        if error is URLError {
            switch (error as? URLError)?.code {
            case .notConnectedToInternet,
                 .networkConnectionLost,
                 .timedOut,
                 .cannotFindHost,
                 .cannotConnectToHost,
                 .dnsLookupFailed:
                return true

            default:
                break
            }
        }

        // Don't retry on HuggingFace errors that indicate client issues
        if let hfError: HuggingFaceError = error as? HuggingFaceError {
            switch hfError {
            case .authenticationRequired,
                 .invalidModel,
                 .unsupportedFormat,
                 .configurationMissing:
                return false

            case .downloadFailed,
                 .networkError,
                 .timeout:
                return true

            default:
                return false
            }
        }

        // Retry on other errors (conservative approach)
        return true
    }
}

/// Simple fixed retry policy for testing
internal struct FixedRetryPolicy: RetryPolicy {
    internal let maxRetries: Int
    private let delay: TimeInterval

    internal init(maxRetries: Int = 3, delay: TimeInterval = 1.0) {
        self.maxRetries = maxRetries
        self.delay = delay
    }

    internal func delayForRetry(attempt _: Int) -> TimeInterval {
        delay
    }

    internal func shouldRetry(error _: Error) -> Bool {
        true
    }
}
