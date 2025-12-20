/// Factory protocol for creating LLM sessions
public protocol LLMFactory {
    /// Creates a new LLM session instance
    /// - Returns: A configured LLM session
    static func createSession() -> LLMSession
}
