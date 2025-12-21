import Abstractions
import Foundation

/// Provider for OpenRouter API.
///
/// OpenRouter provides a unified API for accessing multiple LLM providers
/// including OpenAI, Anthropic, Google, and many open-source models.
/// All models use the same OpenAI-compatible API format.
struct OpenRouterProvider: RemoteProvider {
    // swiftlint:disable:next force_unwrapping
    let baseURL = URL(string: "https://openrouter.ai/api/v1/chat/completions")!

    /// App name for OpenRouter attribution
    let appName: String

    /// App URL for OpenRouter attribution
    let appURL: String

    /// Creates a new OpenRouter provider.
    ///
    /// - Parameters:
    ///   - appName: The name of your application for attribution
    ///   - appURL: The URL of your application for attribution
    init(appName: String = "Think Freely", appURL: String = "https://thinkfreely.app") {
        self.appName = appName
        self.appURL = appURL
    }

    func buildRequest(
        input: LLMInput,
        apiKey: String,
        model: String
    ) throws -> URLRequest {
        var request = URLRequest(url: baseURL)
        request.httpMethod = "POST"

        // Required headers
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        // OpenRouter-specific headers
        request.setValue(appURL, forHTTPHeaderField: "HTTP-Referer")
        request.setValue(appName, forHTTPHeaderField: "X-Title")

        // Build request body
        let body = buildOpenAIRequestBody(input: input, model: model)
        request.httpBody = try JSONEncoder().encode(body)

        return request
    }

    func parseStreamChunk(_ data: String) throws -> StreamParseResult {
        try parseOpenAIChunk(data)
    }
}
