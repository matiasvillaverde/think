import Foundation

/// Types of remote LLM providers.
public enum RemoteProviderType: String, CaseIterable, Sendable {
    case openRouter
    case openAI
    case anthropic
    case google
}
