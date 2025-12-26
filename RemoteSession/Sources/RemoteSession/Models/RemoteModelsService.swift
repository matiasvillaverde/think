import Abstractions
import Foundation

/// Protocol for listing available models from remote providers.
public protocol RemoteModelsProviding: Sendable {
    /// Fetches models available for a provider.
    /// - Parameters:
    ///   - provider: The provider to query.
    ///   - apiKey: API key for authentication (required for most providers).
    func listModels(for provider: RemoteProviderType, apiKey: String?) async throws -> [RemoteModel]
}

/// Service for fetching model lists from remote providers.
public struct RemoteModelsService: RemoteModelsProviding {
    public init() {
        // Public initializer
    }

    public func listModels(
        for provider: RemoteProviderType,
        apiKey: String?
    ) async throws -> [RemoteModel] {
        switch provider {
        case .openRouter:
            return try await fetchOpenRouterModels(apiKey: apiKey)
        case .openAI:
            return try await fetchOpenAIModels(apiKey: apiKey)
        case .anthropic:
            return try await fetchAnthropicModels(apiKey: apiKey)
        case .google:
            return try await fetchGoogleModels(apiKey: apiKey)
        }
    }
}

// MARK: - Provider Fetching

extension RemoteModelsService {
    private func fetchOpenRouterModels(apiKey: String?) async throws -> [RemoteModel] {
        guard let apiKey, !apiKey.isEmpty else {
            throw RemoteModelsServiceError.missingAPIKey(.openRouter)
        }

        guard let url = URL(string: "https://openrouter.ai/api/v1/models") else {
            throw RemoteModelsServiceError.invalidURL
        }
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await URLSession.shared.data(for: request)
        try validateResponse(response, data: data)

        return try RemoteModelsDecoder.decodeOpenRouter(data)
    }

    private func fetchOpenAIModels(apiKey: String?) async throws -> [RemoteModel] {
        guard let apiKey, !apiKey.isEmpty else {
            throw RemoteModelsServiceError.missingAPIKey(.openAI)
        }

        guard let url = URL(string: "https://api.openai.com/v1/models") else {
            throw RemoteModelsServiceError.invalidURL
        }
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await URLSession.shared.data(for: request)
        try validateResponse(response, data: data)

        return try RemoteModelsDecoder.decodeOpenAI(data)
    }

    private func fetchAnthropicModels(apiKey: String?) async throws -> [RemoteModel] {
        guard let apiKey, !apiKey.isEmpty else {
            throw RemoteModelsServiceError.missingAPIKey(.anthropic)
        }

        guard let url = URL(string: "https://api.anthropic.com/v1/models") else {
            throw RemoteModelsServiceError.invalidURL
        }
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")

        let (data, response) = try await URLSession.shared.data(for: request)
        try validateResponse(response, data: data)

        return try RemoteModelsDecoder.decodeAnthropic(data)
    }

    private func fetchGoogleModels(apiKey: String?) async throws -> [RemoteModel] {
        guard let apiKey, !apiKey.isEmpty else {
            throw RemoteModelsServiceError.missingAPIKey(.google)
        }

        guard var components = URLComponents(
            string: "https://generativelanguage.googleapis.com/v1beta/models"
        ) else {
            throw RemoteModelsServiceError.invalidURL
        }
        components.queryItems = [
            URLQueryItem(name: "key", value: apiKey)
        ]

        guard let url = components.url else {
            throw RemoteModelsServiceError.invalidURL
        }
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let (data, response) = try await URLSession.shared.data(for: request)
        try validateResponse(response, data: data)

        return try RemoteModelsDecoder.decodeGoogle(data)
    }

    private func validateResponse(_ response: URLResponse, data: Data) throws {
        guard let http = response as? HTTPURLResponse else {
            throw RemoteModelsServiceError.invalidResponse
        }

        guard (200...299).contains(http.statusCode) else {
            throw RemoteModelsServiceError.httpError(statusCode: http.statusCode, data: data)
        }
    }
}

// MARK: - Error Types

enum RemoteModelsServiceError: Error, Sendable {
    case missingAPIKey(RemoteProviderType)
    case invalidURL
    case invalidResponse
    case httpError(statusCode: Int, data: Data)
}

// MARK: - Decoding Helpers

enum RemoteModelsDecoder {
    static func decodeOpenRouter(_ data: Data) throws -> [RemoteModel] {
        let decoded = try JSONDecoder().decode(OpenRouterModelsResponse.self, from: data)
        return decoded.data.map { model in
            RemoteModel(
                provider: .openRouter,
                modelId: model.id,
                displayName: model.name ?? model.id,
                description: model.description,
                contextLength: model.topProvider?.contextLength ?? model.contextLength,
                type: model.modelType,
                pricing: model.pricingTier
            )
        }
    }

    static func decodeOpenAI(_ data: Data) throws -> [RemoteModel] {
        let decoded = try JSONDecoder().decode(OpenAIModelsResponse.self, from: data)
        return decoded.data.map { model in
            RemoteModel(
                provider: .openAI,
                modelId: model.id,
                displayName: model.id
            )
        }
    }

    static func decodeAnthropic(_ data: Data) throws -> [RemoteModel] {
        let decoded = try JSONDecoder().decode(AnthropicModelsResponse.self, from: data)
        return decoded.data.map { model in
            RemoteModel(
                provider: .anthropic,
                modelId: model.id,
                displayName: model.displayName ?? model.id
            )
        }
    }

    static func decodeGoogle(_ data: Data) throws -> [RemoteModel] {
        let decoded = try JSONDecoder().decode(GoogleModelsResponse.self, from: data)
        return decoded.models.compactMap { model in
            guard model.supportsGeneration else {
                return nil
            }

            return RemoteModel(
                provider: .google,
                modelId: model.preferredModelId,
                displayName: model.displayName ?? model.preferredModelId,
                description: model.description,
                contextLength: model.inputTokenLimit
            )
        }
    }
}

// MARK: - OpenRouter Models

struct OpenRouterModelsResponse: Decodable {
    let data: [OpenRouterModel]
}

struct OpenRouterModel: Decodable {
    let id: String
    let name: String?
    let description: String?
    let contextLength: Int?
    let pricing: OpenRouterPricing?
    let architecture: OpenRouterArchitecture?
    let topProvider: OpenRouterTopProvider?

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case description
        case contextLength = "context_length"
        case pricing
        case architecture
        case topProvider = "top_provider"
    }

    var modelType: SendableModel.ModelType {
        guard let modalities = architecture?.inputModalities else {
            return .language
        }
        if modalities.contains("image") {
            return .visualLanguage
        }
        return .language
    }

    var pricingTier: RemoteModelPricing {
        guard let pricing else {
            return .unknown
        }
        return pricing.isZeroPriced ? .free : .paid
    }
}

struct OpenRouterPricing: Decodable {
    let prompt: String?
    let completion: String?
    let image: String?
    let request: String?

    var isZeroPriced: Bool {
        [prompt, completion, image, request].allSatisfy { value in
            guard let value else {
                return true
            }
            return Double(value) == 0
        }
    }
}

struct OpenRouterArchitecture: Decodable {
    let inputModalities: [String]?
    let outputModalities: [String]?

    enum CodingKeys: String, CodingKey {
        case inputModalities = "input_modalities"
        case outputModalities = "output_modalities"
    }
}

struct OpenRouterTopProvider: Decodable {
    let contextLength: Int?

    enum CodingKeys: String, CodingKey {
        case contextLength = "context_length"
    }
}

// MARK: - OpenAI Models

struct OpenAIModelsResponse: Decodable {
    let data: [OpenAIModel]
}

struct OpenAIModel: Decodable {
    let id: String
}

// MARK: - Anthropic Models

struct AnthropicModelsResponse: Decodable {
    let data: [AnthropicModel]
}

struct AnthropicModel: Decodable {
    let id: String
    let displayName: String?

    enum CodingKeys: String, CodingKey {
        case id
        case displayName = "display_name"
    }
}

// MARK: - Google Models

struct GoogleModelsResponse: Decodable {
    let models: [GoogleModel]
}

struct GoogleModel: Decodable {
    let name: String
    let baseModelId: String?
    let displayName: String?
    let description: String?
    let inputTokenLimit: Int?
    let supportedGenerationMethods: [String]?

    enum CodingKeys: String, CodingKey {
        case name
        case baseModelId
        case displayName
        case description
        case inputTokenLimit
        case supportedGenerationMethods
    }

    var preferredModelId: String {
        if let baseModelId, !baseModelId.isEmpty {
            return baseModelId
        }

        return name.replacingOccurrences(of: "models/", with: "")
    }

    var supportsGeneration: Bool {
        supportedGenerationMethods?.contains("generateContent") == true ||
            supportedGenerationMethods?.contains("streamGenerateContent") == true
    }
}
