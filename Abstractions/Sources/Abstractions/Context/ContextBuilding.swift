import Foundation

/// Protocol for building and processing LLM contexts
public protocol ContextBuilding: Actor {
    /// Process LLM output into structured format
    func process(
        output: String,
        model: SendableModel
    ) async throws -> ProcessedOutput

    /// Get stop sequences for a model
    func getStopSequences(model: SendableModel) -> Set<String>
}
