import Foundation

/// Protocol for building and processing LLM contexts
public protocol ContextBuilding: Actor {
    /// Build a full model context string from parameters (messages, tool schemas, policies, etc).
    func build(parameters: BuildParameters) async throws -> String

    /// Process LLM output into structured format
    func process(
        output: String,
        model: SendableModel
    ) async throws -> ProcessedOutput

    /// Get stop sequences for a model
    func getStopSequences(model: SendableModel) -> Set<String>
}
