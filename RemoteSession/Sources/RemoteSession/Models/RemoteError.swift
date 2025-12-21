import Abstractions
import Foundation

/// Errors specific to remote LLM providers.
enum RemoteError: Error, Sendable {
    /// No API key configured for the provider
    case noAPIKey(RemoteProviderType)

    /// Invalid API key format
    case invalidAPIKey

    /// Provider returned an error response
    case providerError(ProviderErrorResponse)

    /// Failed to parse provider response
    case parseError(String)

    /// Network request failed
    case networkError(Error)

    /// Request was cancelled
    case cancelled

    /// Unknown provider in model location
    case unknownProvider(String)

    /// Invalid model location format
    case invalidModelLocation(String)
}

/// Error response from a remote provider.
struct ProviderErrorResponse: Sendable {
    /// HTTP status code
    let statusCode: Int

    /// Error type/code from provider
    let errorType: String?

    /// Human-readable error message
    let message: String

    /// Retry-after duration for rate limits
    let retryAfter: Duration?
}

/// Maps remote errors to standard LLM errors.
extension RemoteError {
    /// Converts this error to a standard LLMError if applicable.
    func toLLMError() -> LLMError {
        switch self {
        case .noAPIKey(let provider):
            return .authenticationFailed("No API key configured for \(provider.rawValue)")

        case .invalidAPIKey:
            return .authenticationFailed("Invalid API key format")

        case .providerError(let response):
            return mapProviderError(response)

        case .parseError(let message):
            return .providerError(code: "parse_error", message: message)

        case .networkError(let error):
            return .networkError(error)

        case .cancelled:
            return .providerError(code: "cancelled", message: "Request was cancelled")

        case .unknownProvider(let provider):
            return .invalidConfiguration("Unknown provider: \(provider)")

        case .invalidModelLocation(let location):
            return .invalidConfiguration("Invalid model location: \(location)")
        }
    }

    private func mapProviderError(_ response: ProviderErrorResponse) -> LLMError {
        switch response.statusCode {
        case 401:
            return .authenticationFailed(response.message)
        case 403:
            return .authenticationFailed("Access denied: \(response.message)")
        case 404:
            return .modelNotFound(response.message)
        case 429:
            return .rateLimitExceeded(retryAfter: response.retryAfter)
        default:
            return .providerError(
                code: response.errorType ?? "http_\(response.statusCode)",
                message: response.message
            )
        }
    }
}

/// Parses error responses from providers.
enum ErrorResponseParser {
    /// Parses an OpenAI-format error response.
    static func parseOpenAI(_ data: Data, statusCode: Int) -> ProviderErrorResponse {
        struct OpenAIError: Decodable {
            let error: ErrorDetail
            struct ErrorDetail: Decodable {
                let message: String
                let type: String?
                let code: String?
            }
        }

        do {
            let decoded = try JSONDecoder().decode(OpenAIError.self, from: data)
            return ProviderErrorResponse(
                statusCode: statusCode,
                errorType: decoded.error.type ?? decoded.error.code,
                message: decoded.error.message,
                retryAfter: nil
            )
        } catch {
            let message = String(data: data, encoding: .utf8) ?? "Unknown error"
            return ProviderErrorResponse(
                statusCode: statusCode,
                errorType: nil,
                message: message,
                retryAfter: nil
            )
        }
    }

    /// Parses an Anthropic-format error response.
    static func parseAnthropic(_ data: Data, statusCode: Int) -> ProviderErrorResponse {
        struct AnthropicError: Decodable {
            let type: String
            let error: ErrorDetail
            struct ErrorDetail: Decodable {
                let type: String
                let message: String
            }
        }

        do {
            let decoded = try JSONDecoder().decode(AnthropicError.self, from: data)
            return ProviderErrorResponse(
                statusCode: statusCode,
                errorType: decoded.error.type,
                message: decoded.error.message,
                retryAfter: nil
            )
        } catch {
            let message = String(data: data, encoding: .utf8) ?? "Unknown error"
            return ProviderErrorResponse(
                statusCode: statusCode,
                errorType: nil,
                message: message,
                retryAfter: nil
            )
        }
    }
}
