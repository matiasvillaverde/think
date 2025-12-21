import Foundation

/// Response from OpenAI-compatible chat completion API (non-streaming).
struct ChatCompletionResponse: Decodable, Sendable {
    /// Unique identifier for the completion
    let id: String

    /// Object type (always "chat.completion")
    let object: String

    /// Unix timestamp of creation
    let created: Int

    /// Model used for the completion
    let model: String

    /// List of completion choices
    let choices: [Choice]

    /// Token usage information
    let usage: Usage?

    struct Choice: Decodable, Sendable {
        /// Index of this choice
        let index: Int

        /// The generated message
        let message: ResponseMessage

        /// Reason the generation stopped
        let finishReason: String?

        enum CodingKeys: String, CodingKey {
            case index
            case message
            case finishReason = "finish_reason"
        }
    }

    struct ResponseMessage: Decodable, Sendable {
        /// Role of the message (always "assistant")
        let role: String

        /// Content of the message
        let content: String?
    }

    struct Usage: Decodable, Sendable {
        /// Number of tokens in the prompt
        let promptTokens: Int

        /// Number of tokens in the completion
        let completionTokens: Int

        /// Total tokens used
        let totalTokens: Int

        enum CodingKeys: String, CodingKey {
            case promptTokens = "prompt_tokens"
            case completionTokens = "completion_tokens"
            case totalTokens = "total_tokens"
        }
    }
}
