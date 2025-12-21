import Abstractions
import Foundation

/// Provider for Google AI (Gemini) API.
///
/// Google uses a different URL structure and request format than OpenAI.
/// The API key is passed as a query parameter.
struct GoogleProvider: RemoteProvider {
    // swiftlint:disable:next force_unwrapping
    let baseURL = URL(string: "https://generativelanguage.googleapis.com/v1beta/models")!

    func buildRequest(
        input: LLMInput,
        apiKey: String,
        model: String
    ) throws -> URLRequest {
        // Build URL with model and API key
        let streamURL = baseURL
            .appendingPathComponent(model)
            .appendingPathComponent("streamGenerateContent")

        var components = URLComponents(url: streamURL, resolvingAgainstBaseURL: false)
        components?.queryItems = [
            URLQueryItem(name: "key", value: apiKey),
            URLQueryItem(name: "alt", value: "sse")
        ]

        guard let url = components?.url else {
            throw RemoteError.invalidModelLocation("Could not build URL for model: \(model)")
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        // Build Google-format request body
        let body = GeminiRequest(
            contents: [
                GeminiContent(
                    role: "user",
                    parts: [GeminiPart(text: input.context)]
                )
            ],
            generationConfig: GeminiGenerationConfig(
                temperature: input.sampling.temperature,
                topP: input.sampling.topP,
                maxOutputTokens: input.limits.maxTokens,
                stopSequences: input.sampling.stopSequences.isEmpty
                    ? nil
                    : input.sampling.stopSequences
            )
        )

        request.httpBody = try JSONEncoder().encode(body)

        return request
    }

    func parseStreamChunk(_ data: String) throws -> StreamParseResult {
        guard let jsonData = data.data(using: .utf8) else {
            throw RemoteError.parseError("Invalid UTF-8 data")
        }

        let response = try JSONDecoder().decode(GeminiStreamResponse.self, from: jsonData)

        // Extract text from first candidate
        let content = response.candidates?.first?.content.parts.first?.text ?? ""

        // Check finish reason
        let finishReason: FinishReason?
        switch response.candidates?.first?.finishReason {
        case "STOP":
            finishReason = .stop
        case "MAX_TOKENS":
            finishReason = .length
        case "SAFETY":
            finishReason = .contentFilter
        default:
            finishReason = nil
        }

        return StreamParseResult(
            content: content,
            finishReason: finishReason,
            isDone: finishReason != nil
        )
    }

    func parseError(_ data: Data, statusCode: Int) -> ProviderErrorResponse {
        struct GeminiError: Decodable {
            let error: ErrorDetail
            struct ErrorDetail: Decodable {
                let code: Int
                let message: String
                let status: String?
            }
        }

        do {
            let decoded = try JSONDecoder().decode(GeminiError.self, from: data)
            return ProviderErrorResponse(
                statusCode: statusCode,
                errorType: decoded.error.status,
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

// MARK: - Google Request/Response Types

private struct GeminiRequest: Encodable {
    let contents: [GeminiContent]
    let generationConfig: GeminiGenerationConfig?
}

private struct GeminiContent: Codable {
    let role: String
    let parts: [GeminiPart]
}

private struct GeminiPart: Codable {
    let text: String
}

private struct GeminiGenerationConfig: Encodable {
    let temperature: Float?
    let topP: Float?
    let maxOutputTokens: Int?
    let stopSequences: [String]?
}

private struct GeminiStreamResponse: Decodable {
    let candidates: [GeminiCandidate]?

    struct GeminiCandidate: Decodable {
        let content: GeminiContent
        let finishReason: String?
    }
}
