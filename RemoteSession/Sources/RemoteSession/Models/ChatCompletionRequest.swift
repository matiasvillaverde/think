import Foundation

/// Request body for OpenAI-compatible chat completion API.
struct ChatCompletionRequest: Encodable, Sendable {
    /// The model identifier to use for completion
    let model: String

    /// The messages in the conversation
    let messages: [ChatMessage]

    /// Whether to stream the response
    let stream: Bool

    /// Sampling temperature (0.0 to 2.0)
    let temperature: Float?

    /// Top-p sampling parameter
    let topP: Float?

    /// Maximum tokens to generate
    let maxTokens: Int?

    /// Stop sequences
    let stop: [String]?

    /// Frequency penalty (-2.0 to 2.0)
    let frequencyPenalty: Float?

    /// Presence penalty (-2.0 to 2.0)
    let presencePenalty: Float?

    enum CodingKeys: String, CodingKey {
        case model
        case messages
        case stream
        case temperature
        case topP = "top_p"
        case maxTokens = "max_tokens"
        case stop
        case frequencyPenalty = "frequency_penalty"
        case presencePenalty = "presence_penalty"
    }

    /// Creates a new chat completion request.
    init(
        model: String,
        messages: [ChatMessage],
        stream: Bool = true,
        temperature: Float? = nil,
        topP: Float? = nil,
        maxTokens: Int? = nil,
        stop: [String]? = nil,
        frequencyPenalty: Float? = nil,
        presencePenalty: Float? = nil
    ) {
        self.model = model
        self.messages = messages
        self.stream = stream
        self.temperature = temperature
        self.topP = topP
        self.maxTokens = maxTokens
        self.stop = stop
        self.frequencyPenalty = frequencyPenalty
        self.presencePenalty = presencePenalty
    }
}

/// A message in a chat conversation.
struct ChatMessage: Codable, Sendable {
    /// The role of the message author
    let role: Role

    /// The content of the message
    let content: String

    /// The name of the author (optional)
    let name: String?

    enum Role: String, Codable, Sendable {
        case system
        case user
        case assistant
    }

    init(role: Role, content: String, name: String? = nil) {
        self.role = role
        self.content = content
        self.name = name
    }
}
