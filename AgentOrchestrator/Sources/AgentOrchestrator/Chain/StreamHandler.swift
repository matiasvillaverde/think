import Abstractions

// MARK: - Chain of Responsibility for Stream Processing

internal protocol StreamHandler: Sendable {
    var next: StreamHandler? { get set }

    func handleChunk(_ chunk: LLMStreamChunk, state: GenerationState) async throws ->
    StreamAction
}
