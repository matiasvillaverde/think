import Foundation

/// Protocol defining the public interface for agent orchestration
/// This protocol manages the lifecycle and generation of AI agent responses
public protocol AgentOrchestrating: Actor {
    /// The stream of events emitted during generation
    /// Subscribe to this stream to receive real-time updates about generation progress,
    /// tool execution, and other lifecycle events
    var eventStream: AgentEventStream { get async }

    /// Load a chat session for the orchestrator
    /// - Parameter chatId: The unique identifier of the chat to load
    /// - Throws: An error if the chat cannot be loaded
    func load(chatId: UUID) async throws

    /// Unload the currently loaded chat session
    /// - Throws: An error if unloading fails
    func unload() async throws

    /// Generate a response based on the prompt and action
    /// - Parameters:
    ///   - prompt: The user's input prompt
    ///   - action: The type of action to perform (textual or visual)
    /// - Throws: An error if generation fails
    func generate(prompt: String, action: Action) async throws

    /// Stop the current generation process
    /// - Throws: An error if stopping fails
    func stop() async throws

    /// Steer the current generation with a new mode
    /// - Parameter mode: The steering mode to apply
    /// - Note: Steering is applied after the current operation completes
    func steer(mode: SteeringMode) async
}
