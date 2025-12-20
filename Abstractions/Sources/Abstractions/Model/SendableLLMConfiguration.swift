import Foundation

public struct SendableLLMConfiguration: Sendable {
    public let prompt: String

    public let maxTokens: Int

    /// Step size for processing the prompt
    public var prefillStepSize: Int

    /// sampling temperature
    public var temperature: Float

    /// top p sampling
    public var topP: Float

    /// penalty factor for repeating tokens
    public var repetitionPenalty: Float?

    /// number of tokens to consider for repetition penalty
    public var repetitionContextSize: Int

    public init(
        prompt: String,
        maxTokens: Int = 800,
        prefillStepSize: Int = 512,
        temperature: Float = 0.6,
        topP: Float = 1.0,
        repetitionPenalty: Float? = nil,
        repetitionContextSize: Int = 20
    ) {
        self.prompt = prompt
        self.temperature = temperature
        self.maxTokens = maxTokens
        self.prefillStepSize = prefillStepSize
        self.topP = topP
        self.repetitionPenalty = repetitionPenalty
        self.repetitionContextSize = repetitionContextSize
    }
}
