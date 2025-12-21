import Foundation

/// A streaming response chunk from OpenAI-compatible chat completion API.
struct StreamChunk: Decodable, Sendable {
    /// Unique identifier for the completion
    let id: String

    /// Object type (always "chat.completion.chunk")
    let object: String

    /// Unix timestamp of creation
    let created: Int

    /// Model used for the completion
    let model: String

    /// List of completion choices
    let choices: [StreamChoice]

    /// Token usage information (may be included in final chunk)
    let usage: ChatCompletionResponse.Usage?

    struct StreamChoice: Decodable, Sendable {
        /// Index of this choice
        let index: Int

        /// The delta (partial) content
        let delta: Delta

        /// Reason the generation stopped (only in final chunk)
        let finishReason: String?

        enum CodingKeys: String, CodingKey {
            case index
            case delta
            case finishReason = "finish_reason"
        }
    }

    struct Delta: Decodable, Sendable {
        /// Role of the message (only in first chunk)
        let role: String?

        /// Partial content of the message
        let content: String?
    }
}

/// Finish reasons for chat completions.
enum FinishReason: String, Sendable {
    /// Model completed naturally
    case stop

    /// Maximum tokens reached
    case length

    /// Content was filtered
    case contentFilter = "content_filter"

    /// Tool/function call requested
    case toolCalls = "tool_calls"

    /// Function call requested (deprecated, use toolCalls)
    case functionCall = "function_call"
}
