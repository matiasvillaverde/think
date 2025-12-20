import Foundation

/// Common errors that providers may throw.
///
/// Providers should throw these standard errors when possible to ensure
/// consistent error handling across different implementations.
public enum LLMError: Error, Sendable {
    /// Authentication failed (invalid API key, expired token, etc.).
    case authenticationFailed(String)

    /// Rate limit exceeded. Includes retry-after duration if available.
    case rateLimitExceeded(retryAfter: Duration?)

    /// Requested model is not available or doesn't exist.
    case modelNotFound(String)

    /// Invalid configuration parameters.
    case invalidConfiguration(String)

    /// Network-related errors.
    case networkError(Error)

    /// Provider-specific errors that don't fit standard categories.
    case providerError(code: String, message: String)
}
