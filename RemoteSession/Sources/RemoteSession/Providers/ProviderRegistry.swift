import Foundation

/// Types of remote LLM providers.
public enum RemoteProviderType: String, CaseIterable, Sendable {
    case openRouter
    case openAI
    case anthropic
    case google

    /// The keychain service identifier for this provider
    var keychainKey: String {
        "api_key_\(rawValue)"
    }
}

/// Registry for resolving providers from model locations.
///
/// Model locations follow the format: `provider:model-identifier`
/// For example:
/// - `openrouter:google/gemini-2.0-flash-exp:free`
/// - `openai:gpt-4o-mini`
/// - `anthropic:claude-3-haiku-20240307`
/// - `google:gemini-1.5-flash`
enum ProviderRegistry {
    /// Resolves a provider and model from a location string.
    ///
    /// - Parameter location: The model location (e.g., "openrouter:google/gemini-2.0")
    /// - Returns: A tuple of (provider, model identifier)
    /// - Throws: If the provider is unknown or the location is invalid
    static func resolve(_ location: String) throws -> (RemoteProvider, String) {
        // Parse provider prefix
        guard let colonIndex = location.firstIndex(of: ":") else {
            throw RemoteError.invalidModelLocation(
                "Model location must be in format 'provider:model'. Got: \(location)"
            )
        }

        let providerName = String(location[..<colonIndex]).lowercased()
        let modelId = String(location[location.index(after: colonIndex)...])

        guard !modelId.isEmpty else {
            throw RemoteError.invalidModelLocation(
                "Model identifier cannot be empty. Got: \(location)"
            )
        }

        let providerType = try parseProviderType(providerName)
        let provider = createProvider(for: providerType)

        return (provider, modelId)
    }

    /// Parses a provider type from a string.
    ///
    /// - Parameter name: The provider name (e.g., "openrouter", "openai")
    /// - Returns: The corresponding provider type
    /// - Throws: If the provider is unknown
    static func parseProviderType(_ name: String) throws -> RemoteProviderType {
        switch name {
        case "openrouter":
            return .openRouter
        case "openai":
            return .openAI
        case "anthropic":
            return .anthropic
        case "google", "gemini":
            return .google
        default:
            throw RemoteError.unknownProvider(name)
        }
    }

    /// Creates a provider instance for the given type.
    ///
    /// - Parameter type: The provider type
    /// - Returns: A configured provider instance
    static func createProvider(for type: RemoteProviderType) -> RemoteProvider {
        switch type {
        case .openRouter:
            return OpenRouterProvider()
        case .openAI:
            return OpenAIProvider()
        case .anthropic:
            return AnthropicProvider()
        case .google:
            return GoogleProvider()
        }
    }
}
