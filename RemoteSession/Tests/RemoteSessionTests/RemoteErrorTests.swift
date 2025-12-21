import Abstractions
import Foundation
import Testing
@testable import RemoteSession

@Suite("Remote Error Tests")
struct RemoteErrorTests {
    @Test("Map 401 to authentication failed")
    func map401ToAuthenticationFailed() {
        let response = ProviderErrorResponse(
            statusCode: 401,
            errorType: "invalid_api_key",
            message: "Invalid API key",
            retryAfter: nil
        )

        let llmError = RemoteError.providerError(response).toLLMError()

        if case .authenticationFailed(let message) = llmError {
            #expect(message == "Invalid API key")
        } else {
            #expect(false, "Expected authenticationFailed error")
        }
    }

    @Test("Map 429 to rate limit exceeded")
    func map429ToRateLimitExceeded() {
        let response = ProviderErrorResponse(
            statusCode: 429,
            errorType: "rate_limit_exceeded",
            message: "Rate limit exceeded",
            retryAfter: .seconds(60)
        )

        let llmError = RemoteError.providerError(response).toLLMError()

        if case .rateLimitExceeded(let retryAfter) = llmError {
            #expect(retryAfter == .seconds(60))
        } else {
            #expect(false, "Expected rateLimitExceeded error")
        }
    }

    @Test("Map 404 to model not found")
    func map404ToModelNotFound() {
        let response = ProviderErrorResponse(
            statusCode: 404,
            errorType: "model_not_found",
            message: "Model gpt-5 not found",
            retryAfter: nil
        )

        let llmError = RemoteError.providerError(response).toLLMError()

        if case .modelNotFound(let message) = llmError {
            #expect(message == "Model gpt-5 not found")
        } else {
            #expect(false, "Expected modelNotFound error")
        }
    }

    @Test("Map 500 to provider error")
    func map500ToProviderError() {
        let response = ProviderErrorResponse(
            statusCode: 500,
            errorType: "internal_error",
            message: "Internal server error",
            retryAfter: nil
        )

        let llmError = RemoteError.providerError(response).toLLMError()

        if case .providerError(let code, let message) = llmError {
            #expect(code == "internal_error")
            #expect(message == "Internal server error")
        } else {
            #expect(false, "Expected providerError")
        }
    }

    @Test("Parse OpenAI error response JSON")
    func parseOpenAIErrorResponseJSON() {
        let json = """
        {
            "error": {
                "message": "Invalid API key provided",
                "type": "invalid_request_error",
                "code": "invalid_api_key"
            }
        }
        """

        let data = Data(json.utf8)
        let response = ErrorResponseParser.parseOpenAI(data, statusCode: 401)

        #expect(response.statusCode == 401)
        #expect(response.message == "Invalid API key provided")
        #expect(response.errorType == "invalid_request_error")
    }

    @Test("Parse Anthropic error response JSON")
    func parseAnthropicErrorResponseJSON() {
        let json = """
        {
            "type": "error",
            "error": {
                "type": "authentication_error",
                "message": "Invalid x-api-key"
            }
        }
        """

        let data = Data(json.utf8)
        let response = ErrorResponseParser.parseAnthropic(data, statusCode: 401)

        #expect(response.statusCode == 401)
        #expect(response.message == "Invalid x-api-key")
        #expect(response.errorType == "authentication_error")
    }

    @Test("Handle malformed error response")
    func handleMalformedErrorResponse() {
        let data = Data("Not JSON".utf8)
        let response = ErrorResponseParser.parseOpenAI(data, statusCode: 500)

        #expect(response.statusCode == 500)
        #expect(response.message == "Not JSON")
    }

    @Test("Map noAPIKey to authentication failed")
    func mapNoAPIKeyToAuthenticationFailed() {
        let error = RemoteError.noAPIKey(.openAI)
        let llmError = error.toLLMError()

        if case .authenticationFailed(let message) = llmError {
            #expect(message.contains("openAI"))
        } else {
            #expect(false, "Expected authenticationFailed error")
        }
    }

    @Test("Map unknownProvider to invalid configuration")
    func mapUnknownProviderToInvalidConfiguration() {
        let error = RemoteError.unknownProvider("foo")
        let llmError = error.toLLMError()

        if case .invalidConfiguration(let message) = llmError {
            #expect(message.contains("foo"))
        } else {
            #expect(false, "Expected invalidConfiguration error")
        }
    }
}
