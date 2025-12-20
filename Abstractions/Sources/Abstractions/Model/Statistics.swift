import Foundation

@available(*, deprecated, renamed: "Metrics", message: "We should remove it")
public struct Statistics: Sendable {
    /// Active memory usage
    public let activeMemory: UInt64

    /// Cache memory usage
    public let cacheMemory: UInt64

    /// Peak memory usage
    public let peakMemory: UInt64

    /// Time taken to load the model
    public let modelLoadTime: TimeInterval

    /// Time to process the prompt / generate the first token
    public let promptTime: TimeInterval

    /// Time to generate the remaining tokens
    public let generateTime: TimeInterval

    /// Rate of prompt token processing
    public let promptTokensPerSecond: Double

    /// Overall token generation rate
    public let tokensPerSecond: Double

    /// Count of tokens in the response
    public let responseTokenCount: UInt

    /// Count of tokens in the prompt
    public let promptTokenCount: UInt

    /// Number of model parameters
    public let numParameters: Int

    public init(
        activeMemory: UInt64,
        cacheMemory: UInt64,
        peakMemory: UInt64,
        modelLoadTime: TimeInterval,
        promptTime: TimeInterval,
        generateTime: TimeInterval,
        promptTokensPerSecond: Double,
        tokensPerSecond: Double,
        responseTokenCount: UInt,
        promptTokenCount: UInt,
        numParameters: Int
    ) {
        self.activeMemory = activeMemory
        self.cacheMemory = cacheMemory
        self.peakMemory = peakMemory
        self.modelLoadTime = modelLoadTime
        self.promptTime = promptTime
        self.generateTime = generateTime
        self.promptTokensPerSecond = promptTokensPerSecond
        self.tokensPerSecond = tokensPerSecond
        self.responseTokenCount = responseTokenCount
        self.promptTokenCount = promptTokenCount
        self.numParameters = numParameters
    }
}
