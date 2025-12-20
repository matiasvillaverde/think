import Abstractions
import Foundation

/// Factory for creating LLM sessions backed by llama.cpp
///
/// This is the ONLY public interface for the LLamaCPP module.
/// All internal implementation details are hidden behind this factory pattern.
///
/// Usage:
/// ```swift
/// let configuration = ProviderConfiguration(
///     location: URL(fileURLWithPath: "/path/to/model.gguf"),
///     authentication: .noAuth,
///     modelName: "llama-2-7b",
///     compute: .medium
/// )
/// let session = await LlamaCPPFactory.createSession(configuration: configuration)
/// ```
public enum LlamaCPPFactory: LLMFactory {
    /// Creates a new LLM session with the provided configuration
    ///
    /// This method initializes a llama.cpp-backed session that conforms to the
    /// LLMSession protocol. The actual implementation (LlamaCPPSession) is hidden
    /// from the caller, providing a clean abstraction boundary.
    ///
    /// - Parameter configuration: The provider configuration specifying model path,
    ///   authentication, model name, and compute resources
    /// - Returns: An LLMSession instance ready for text generation
    ///
    /// - Note: The session is an actor and all operations on it are thread-safe.
    ///   The model will be lazily loaded on first use unless explicitly preloaded.
    public static func createSession() -> LLMSession {
        // Create and return the session
        // The type is LLMSession (protocol) but the implementation is LlamaCPPSession
        LlamaCPPSession()
    }
}
