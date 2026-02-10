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
        if isOpenRouterPrivacyPolicyBlock(response) {
            return .invalidConfiguration(
                """
                OpenRouter blocked this request due to your data policy. \
                Update your OpenRouter privacy settings to allow an endpoint for this model and retry. \
                (OpenRouter: Settings -> Privacy)
                """
            )
        }

        switch response.statusCode {
        case 401:
            if isMissingAuthCredentials(response.message) {
                return .authenticationFailed(
                    """
                    Missing or invalid API key. Add or update your API key for this provider and retry.
                    """
                )
            }
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

    private func isOpenRouterPrivacyPolicyBlock(_ response: ProviderErrorResponse) -> Bool {
        // OpenRouter can return plain text bodies for some policy failures.
        // Example:
        // "No endpoints found matching your data policy (Free model publication). Configure:"
        // "https://openrouter.ai/settings/privacy"
        response.message.localizedCaseInsensitiveContains("No endpoints found matching your data policy")
    }

    private func isMissingAuthCredentials(_ message: String) -> Bool {
        // Some gateways (and certain provider proxies) return this 401 message when no API key is sent.
        // Normalize it into actionable guidance instead of leaking gateway wording.
        let lowered = message.lowercased()
        return lowered.contains("no cookie auth credentials found") ||
            lowered.contains("no auth credentials found") ||
            lowered.contains("missing authentication")
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

                init(from decoder: Decoder) throws {
                    let container = try decoder.container(keyedBy: CodingKeys.self)
                    self.message = try container.decode(String.self, forKey: .message)
                    self.type = try container.decodeIfPresent(String.self, forKey: .type)

                    // `code` is inconsistently typed across providers (String vs Int).
                    if let codeString = try? container.decode(String.self, forKey: .code) {
                        self.code = codeString
                    } else if let codeInt = try? container.decode(Int.self, forKey: .code) {
                        self.code = String(codeInt)
                    } else {
                        self.code = nil
                    }
                }

                private enum CodingKeys: String, CodingKey {
                    case message
                    case type
                    case code
                }
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
