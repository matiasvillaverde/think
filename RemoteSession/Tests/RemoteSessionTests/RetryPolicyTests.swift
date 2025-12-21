import Foundation
import Testing
@testable import RemoteSession

@Suite("Retry Policy Tests")
struct RetryPolicyTests {
    @Test("Calculate backoff delays correctly")
    func calculateBackoffDelays() {
        let policy = RetryPolicy(
            maxRetries: 3,
            baseDelay: 1.0,
            maxDelay: 10.0,
            jitterFactor: 0.0 // No jitter for deterministic testing
        )

        // First attempt: 1.0 * 2^0 = 1.0
        let delay0 = policy.delay(forAttempt: 0)
        #expect(delay0 == 1.0)

        // Second attempt: 1.0 * 2^1 = 2.0
        let delay1 = policy.delay(forAttempt: 1)
        #expect(delay1 == 2.0)

        // Third attempt: 1.0 * 2^2 = 4.0
        let delay2 = policy.delay(forAttempt: 2)
        #expect(delay2 == 4.0)

        // Fourth attempt: min(1.0 * 2^3, 10.0) = 8.0
        let delay3 = policy.delay(forAttempt: 3)
        #expect(delay3 == 8.0)

        // Fifth attempt: min(1.0 * 2^4, 10.0) = 10.0 (capped)
        let delay4 = policy.delay(forAttempt: 4)
        #expect(delay4 == 10.0)
    }

    @Test("Respect max retry count")
    func respectMaxRetryCount() {
        let policy = RetryPolicy(
            maxRetries: 3,
            baseDelay: 1.0,
            maxDelay: 10.0,
            jitterFactor: 0.0
        )

        // Should retry for attempts 0, 1, 2
        #expect(policy.shouldRetry(error: HTTPError.timeout, attempt: 0))
        #expect(policy.shouldRetry(error: HTTPError.timeout, attempt: 1))
        #expect(policy.shouldRetry(error: HTTPError.timeout, attempt: 2))

        // Should not retry for attempt 3 (exhausted)
        #expect(!policy.shouldRetry(error: HTTPError.timeout, attempt: 3))
    }

    @Test("Add jitter within bounds")
    func addJitterWithinBounds() {
        let policy = RetryPolicy(
            maxRetries: 3,
            baseDelay: 1.0,
            maxDelay: 10.0,
            jitterFactor: 0.2
        )

        // Run multiple times to test jitter range
        for _ in 0..<100 {
            let delay = policy.delay(forAttempt: 0)
            // Base delay is 1.0, jitter is ±20%, so range is 0.8 to 1.2
            #expect(delay >= 0.8)
            #expect(delay <= 1.2)
        }
    }

    @Test("No retry for non-retryable errors")
    func noRetryForNonRetryableErrors() {
        let policy = RetryPolicy.default

        // 401 Unauthorized - not retryable
        let authError = HTTPError.statusCode(401, Data())
        #expect(!policy.shouldRetry(error: authError, attempt: 0))

        // 404 Not Found - not retryable
        let notFoundError = HTTPError.statusCode(404, Data())
        #expect(!policy.shouldRetry(error: notFoundError, attempt: 0))

        // Invalid response - not retryable
        #expect(!policy.shouldRetry(error: HTTPError.invalidResponse, attempt: 0))

        // Cancelled - not retryable
        #expect(!policy.shouldRetry(error: HTTPError.cancelled, attempt: 0))
    }

    @Test("Retry for rate limit errors")
    func retryForRateLimitErrors() {
        let policy = RetryPolicy.default

        // 429 Too Many Requests - retryable
        let rateLimitError = HTTPError.statusCode(429, Data())
        #expect(policy.shouldRetry(error: rateLimitError, attempt: 0))
    }

    @Test("Retry for server errors")
    func retryForServerErrors() {
        let policy = RetryPolicy.default

        // 500 Internal Server Error - retryable
        #expect(policy.shouldRetry(error: HTTPError.statusCode(500, Data()), attempt: 0))

        // 502 Bad Gateway - retryable
        #expect(policy.shouldRetry(error: HTTPError.statusCode(502, Data()), attempt: 0))

        // 503 Service Unavailable - retryable
        #expect(policy.shouldRetry(error: HTTPError.statusCode(503, Data()), attempt: 0))

        // 504 Gateway Timeout - retryable
        #expect(policy.shouldRetry(error: HTTPError.statusCode(504, Data()), attempt: 0))
    }

    @Test("Retry for timeout errors")
    func retryForTimeoutErrors() {
        let policy = RetryPolicy.default

        #expect(policy.shouldRetry(error: HTTPError.timeout, attempt: 0))
    }
}
