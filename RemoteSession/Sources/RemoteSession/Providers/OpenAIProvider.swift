import Abstractions
import Foundation

/// Provider for OpenAI API.
///
/// Direct access to OpenAI models (GPT-4, GPT-4o, etc.).
struct OpenAIProvider: RemoteProvider {
    // swiftlint:disable:next force_unwrapping
    let baseURL = URL(string: "https://api.openai.com/v1/chat/completions")!

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

        // Build request body
        let body = buildOpenAIRequestBody(input: input, model: model)
        request.httpBody = try JSONEncoder().encode(body)

        return request
    }

    func parseStreamChunk(_ data: String) throws -> StreamParseResult {
        try parseOpenAIChunk(data)
    }
}
