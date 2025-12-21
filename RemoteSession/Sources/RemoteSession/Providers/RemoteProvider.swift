import Abstractions
import Foundation

/// Protocol for remote LLM API providers.
///
/// Each provider implements this protocol to handle the specifics
/// of building requests and parsing responses for their API.
protocol RemoteProvider: Sendable {
    /// The base URL for the API
    var baseURL: URL { get }

    /// Builds a URL request for a chat completion.
    ///
    /// - Parameters:
    ///   - input: The LLM input configuration
    ///   - apiKey: The API key for authentication
    ///   - model: The model identifier
    /// - Returns: A configured URL request
    /// - Throws: If the request cannot be built
    func buildRequest(
        input: LLMInput,
        apiKey: String,
        model: String
    ) throws -> URLRequest

    /// Parses a streaming chunk from the provider's response format.
    ///
    /// - Parameter data: The raw event data
    /// - Returns: The parsed content and optional finish reason
    /// - Throws: If parsing fails
    func parseStreamChunk(_ data: String) throws -> StreamParseResult

    /// Parses an error response from the provider.
    ///
    /// - Parameters:
    ///   - data: The error response body
    ///   - statusCode: The HTTP status code
    /// - Returns: A parsed error response
    func parseError(_ data: Data, statusCode: Int) -> ProviderErrorResponse
}

/// Result of parsing a streaming chunk.
struct StreamParseResult: Sendable {
    /// The text content from this chunk (may be empty)
    let content: String

    /// The finish reason if generation completed
    let finishReason: FinishReason?

    /// Whether this chunk indicates the stream is done
    let isDone: Bool

    /// Token usage metrics if available
    let usage: ChatCompletionResponse.Usage?

    init(
        content: String = "",
        finishReason: FinishReason? = nil,
        isDone: Bool = false,
        usage: ChatCompletionResponse.Usage? = nil
    ) {
        self.content = content
        self.finishReason = finishReason
        self.isDone = isDone
        self.usage = usage
    }
}

/// Common request building utilities for providers.
extension RemoteProvider {
    /// Builds a standard OpenAI-format request body.
    func buildOpenAIRequestBody(
        input: LLMInput,
        model: String
    ) -> ChatCompletionRequest {
        // Convert context to messages
        // For simplicity, we treat the entire context as a user message
        // In a real implementation, you might parse chat history
        let messages = [
            ChatMessage(role: .user, content: input.context)
        ]

        return ChatCompletionRequest(
            model: model,
            messages: messages,
            stream: true,
            temperature: input.sampling.temperature,
            topP: input.sampling.topP,
            maxTokens: input.limits.maxTokens,
            stop: input.sampling.stopSequences.isEmpty
                ? nil
                : input.sampling.stopSequences
        )
    }

    /// Default OpenAI-format chunk parsing.
    func parseOpenAIChunk(_ data: String) throws -> StreamParseResult {
        // Check for done marker
        if SSEParser.isDone(data) {
            return StreamParseResult(isDone: true)
        }

        // Parse JSON
        guard let jsonData = data.data(using: .utf8) else {
            throw RemoteError.parseError("Invalid UTF-8 data")
        }

        let chunk = try JSONDecoder().decode(StreamChunk.self, from: jsonData)

        // Extract content from first choice
        let content = chunk.choices.first?.delta.content ?? ""
        let finishReason = chunk.choices.first?.finishReason.flatMap { FinishReason(rawValue: $0) }

        return StreamParseResult(
            content: content,
            finishReason: finishReason,
            isDone: finishReason != nil,
            usage: chunk.usage
        )
    }

    /// Default error parsing.
    func parseError(_ data: Data, statusCode: Int) -> ProviderErrorResponse {
        ErrorResponseParser.parseOpenAI(data, statusCode: statusCode)
    }
}
