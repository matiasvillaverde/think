import Abstractions
import Foundation

// MARK: - RemoteProviderType Display Extensions

extension RemoteProviderType {
    /// User-friendly display name for the provider.
    public var displayName: String {
        switch self {
        case .openRouter:
            return "OpenRouter"

        case .openAI:
            return "OpenAI"

        case .anthropic:
            return "Anthropic"

        case .google:
            return "Google"
        }
    }

    /// Description of what this provider offers.
    public var description: String {
        switch self {
        case .openRouter:
            return "Access to multiple LLM providers through a unified API"

        case .openAI:
            return "GPT-4, GPT-4o, and other OpenAI models"

        case .anthropic:
            return "Claude 3 and Claude 3.5 models"

        case .google:
            return "Gemini Pro and Gemini Flash models"
        }
    }

    /// The URL to sign up or get an API key for this provider.
    public var signUpURL: URL? {
        switch self {
        case .openRouter:
            return URL(string: "https://openrouter.ai/keys")

        case .openAI:
            return URL(string: "https://platform.openai.com/api-keys")

        case .anthropic:
            return URL(string: "https://console.anthropic.com/settings/keys")

        case .google:
            return URL(string: "https://aistudio.google.com/apikey")
        }
    }
}
