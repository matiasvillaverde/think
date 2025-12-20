import Foundation

/// Protocol for view models that handle generation operations
public protocol ViewModelGenerating: Actor {
    /// Loads resources for a chat session
    /// - Parameter chatId: The chat session identifier
    func load(chatId: UUID) async
    /// Unloads resources to free up memory
    func unload() async
    /// Generates a response for the given prompt
    /// - Parameters:
    ///   - prompt: The user's input prompt
    ///   - overrideAction: Optional action to override default behavior
    func generate(prompt: String, overrideAction: Action?) async
    /// Stops the current generation process
    func stop() async
    /// Modifies the model for a chat session
    /// - Parameters:
    ///   - chatId: The chat session identifier
    ///   - modelId: The new model identifier
    func modify(chatId: UUID, modelId: UUID) async
}
