import Abstractions
import Foundation

/// Provider for Anthropic API.
///
/// Anthropic uses a different API format than OpenAI, with its own
/// message structure and streaming format.
struct AnthropicProvider: RemoteProvider {
    // swiftlint:disable:next force_unwrapping
    let baseURL = URL(string: "https://api.anthropic.com/v1/messages")!

    /// Anthropic API version
    let apiVersion = "2023-06-01"

    func buildRequest(
        input: LLMInput,
        apiKey: String,
        model: String
    ) throws -> URLRequest {
        var request = URLRequest(url: baseURL)
        request.httpMethod = "POST"

        // Required headers
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue(apiVersion, forHTTPHeaderField: "anthropic-version")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        // Build Anthropic-format request body
        let body = AnthropicRequest(
            model: model,
            messages: [
                AnthropicMessage(role: "user", content: input.context)
            ],
            maxTokens: input.limits.maxTokens,
            stream: true,
            temperature: input.sampling.temperature,
            topP: input.sampling.topP,
            stopSequences: input.sampling.stopSequences.isEmpty
                ? nil
                : input.sampling.stopSequences
        )

        request.httpBody = try JSONEncoder().encode(body)

        return request
    }

    func parseStreamChunk(_ data: String) throws -> StreamParseResult {
        // Check for done marker
        if SSEParser.isDone(data) {
            return StreamParseResult(isDone: true)
        }

        guard let jsonData = data.data(using: .utf8) else {
            throw RemoteError.parseError("Invalid UTF-8 data")
        }

        let event = try JSONDecoder().decode(AnthropicStreamEvent.self, from: jsonData)

        switch event.type {
        case "content_block_delta":
            let content = event.delta?.text ?? ""
            return StreamParseResult(content: content)

        case "message_delta":
            // Final message with stop reason
            let finishReason: FinishReason?
            switch event.delta?.stopReason {
            case "end_turn":
                finishReason = .stop
            case "max_tokens":
                finishReason = .length
            case "stop_sequence":
                finishReason = .stop
            default:
                finishReason = nil
            }
            return StreamParseResult(finishReason: finishReason, isDone: finishReason != nil)

        case "message_stop":
            return StreamParseResult(isDone: true)

        default:
            // Ignore other event types (message_start, content_block_start, etc.)
            return StreamParseResult()
        }
    }

    func parseError(_ data: Data, statusCode: Int) -> ProviderErrorResponse {
        ErrorResponseParser.parseAnthropic(data, statusCode: statusCode)
    }
}

// MARK: - Anthropic Request/Response Types

private struct AnthropicRequest: Encodable {
    let model: String
    let messages: [AnthropicMessage]
    let maxTokens: Int
    let stream: Bool
    let temperature: Float?
    let topP: Float?
    let stopSequences: [String]?

    enum CodingKeys: String, CodingKey {
        case model
        case messages
        case maxTokens = "max_tokens"
        case stream
        case temperature
        case topP = "top_p"
        case stopSequences = "stop_sequences"
    }
}

private struct AnthropicMessage: Encodable {
    let role: String
    let content: String
}

private struct AnthropicStreamEvent: Decodable {
    let type: String
    let delta: Delta?

    struct Delta: Decodable {
        let type: String?
        let text: String?
        let stopReason: String?

        enum CodingKeys: String, CodingKey {
            case type
            case text
            case stopReason = "stop_reason"
        }
    }
}
