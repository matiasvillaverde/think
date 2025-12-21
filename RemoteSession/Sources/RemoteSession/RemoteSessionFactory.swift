import Abstractions
import Foundation

/// Factory for creating LLM sessions backed by remote API providers.
///
/// This is the primary public interface for the RemoteSession module.
/// All internal implementation details are hidden behind this factory pattern.
///
/// Usage:
/// ```swift
/// let session = RemoteSessionFactory.create()
///
/// // Configure with provider configuration
/// for try await _ in await session.preload(configuration: config) { }
///
/// // Stream generation
/// for try await chunk in await session.stream(input) {
///     print(chunk.text)
/// }
/// ```
public enum RemoteSessionFactory {
    /// Creates a new remote LLM session.
    ///
    /// This method creates a session that can connect to various remote
    /// LLM providers (OpenRouter, OpenAI, Anthropic, Google) based on
    /// the model location in the configuration.
    ///
    /// - Returns: An LLMSession instance ready for remote text generation
    ///
    /// - Note: The session is an actor and all operations on it are thread-safe.
    ///   API keys must be configured via `APIKeyManager` before streaming.
    public static func create() -> LLMSession {
        RemoteSession()
    }

    /// Creates a new remote LLM session with a custom API key manager.
    ///
    /// This method is primarily used for testing, allowing injection of
    /// mock API key managers.
    ///
    /// - Parameter apiKeyManager: The API key manager to use for retrieving keys
    /// - Returns: An LLMSession instance configured with the provided key manager
    public static func create(apiKeyManager: APIKeyManaging) -> LLMSession {
        RemoteSession(apiKeyManager: apiKeyManager)
    }
}
