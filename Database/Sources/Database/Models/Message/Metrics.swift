import Foundation
import SwiftData

/// Comprehensive metrics model that captures all ChunkMetrics data
@Model
public final class Metrics: Identifiable, Equatable {
    // MARK: - Identity
    
    @Attribute()
    public private(set) var id: UUID = UUID()
    
    @Attribute()
    public private(set) var createdAt: Date = Date()
    
    // MARK: - Timing Metrics (from TimingMetrics)
    
    /// Total time for the entire generation process
    @Attribute()
    public private(set) var totalTime: TimeInterval = 0
    
    /// Time from start to first token generation
    @Attribute()
    public private(set) var timeToFirstToken: TimeInterval?
    
    /// Time since the last token was generated
    @Attribute()
    public private(set) var timeSinceLastToken: TimeInterval?
    
    /// Time spent processing the prompt
    @Attribute()
    public private(set) var promptProcessingTime: TimeInterval?
    
    /// Individual token generation timings (stored as array of TimeIntervals)
    @Attribute()
    public private(set) var tokenTimings: [TimeInterval] = []
    
    // MARK: - Usage Metrics (from UsageMetrics)
    
    /// Number of tokens in the prompt
    @Attribute()
    public private(set) var promptTokens: Int = 0
    
    /// Number of tokens generated
    @Attribute()
    public private(set) var generatedTokens: Int = 0
    
    /// Total tokens (prompt + generated)
    @Attribute()
    public private(set) var totalTokens: Int = 0
    
    /// Size of the context window
    @Attribute()
    public private(set) var contextWindowSize: Int?
    
    /// Number of context tokens actually used
    @Attribute()
    public private(set) var contextTokensUsed: Int?
    
    /// KV cache size in bytes
    @Attribute()
    public private(set) var kvCacheBytes: Int64?
    
    /// Number of entries in KV cache
    @Attribute()
    public private(set) var kvCacheEntries: Int?
    
    // MARK: - Generation Metrics (from GenerationMetrics)
    
    /// Token IDs generated (vocabulary indices)
    @Attribute()
    public private(set) var tokenIds: [Int32] = []
    
    /// Token text representations
    @Attribute()
    public private(set) var tokenTexts: [String] = []
    
    /// Log probabilities for each token
    @Attribute()
    public private(set) var tokenLogProbs: [Float32] = []
    
    /// Duration for generating each token (parallel to tokenIds)
    @Attribute()
    public private(set) var tokenDurations: [TimeInterval] = []
    
    /// Reason generation stopped (stored as String, will map from enum)
    @Attribute()
    public private(set) var stopReason: String?
    
    /// Temperature used for sampling
    @Attribute()
    public private(set) var temperature: Float32?
    
    /// Top-p value used for sampling
    @Attribute()
    public private(set) var topP: Float32?
    
    /// Top-k value used for sampling
    @Attribute()
    public private(set) var topK: Int32?
    
    // MARK: - Legacy Statistics Fields (for compatibility during migration)
    
    /// Active memory usage
    @Attribute()
    public private(set) var activeMemory: UInt64 = 0
    
    /// Cache memory usage
    @Attribute()
    public private(set) var cacheMemory: UInt64 = 0
    
    /// Peak memory usage
    @Attribute()
    public private(set) var peakMemory: UInt64 = 0
    
    /// Time taken to load the model
    @Attribute()
    public private(set) var modelLoadTime: TimeInterval = 0
    
    /// Number of model parameters
    @Attribute()
    public private(set) var numParameters: Int = 0
    
    // MARK: - Calculated Metrics (stored for performance)
    
    /// Perplexity - measure of model confidence
    @Attribute()
    public private(set) var perplexity: Double?
    
    /// Entropy - measure of randomness/uncertainty
    @Attribute()
    public private(set) var entropy: Double?
    
    /// Repetition rate - measure of token repetition
    @Attribute()
    public private(set) var repetitionRate: Double?
    
    /// Context utilization - percentage of context window used
    @Attribute()
    public private(set) var contextUtilization: Double?
    
    /// Model name/identifier
    @Attribute()
    public private(set) var modelName: String?
    
    /// Timing percentiles
    @Attribute()
    public private(set) var timeToFirstTokenP50: Double?
    
    @Attribute()
    public private(set) var timeToFirstTokenP95: Double?
    
    @Attribute()
    public private(set) var timeToFirstTokenP99: Double?
    
    // MARK: - Computed Properties
    
    /// Tokens per second during generation
    public var tokensPerSecond: Double {
        guard totalTime > 0, generatedTokens > 0 else { return 0 }
        return Double(generatedTokens) / totalTime
    }
    
    /// Prompt tokens per second
    public var promptTokensPerSecond: Double {
        guard let promptTime = promptProcessingTime, promptTime > 0, promptTokens > 0 else { return 0 }
        return Double(promptTokens) / promptTime
    }
    
    /// Average time per token
    public var averageTimePerToken: TimeInterval? {
        guard !tokenTimings.isEmpty else { return nil }
        return tokenTimings.reduce(0, +) / Double(tokenTimings.count)
    }
    
    // MARK: - Relationships
    
    @Relationship
    public private(set) var message: Message?
    
    // MARK: - Initializers
    
    public init(
        totalTime: TimeInterval = 0,
        timeToFirstToken: TimeInterval? = nil,
        timeSinceLastToken: TimeInterval? = nil,
        promptProcessingTime: TimeInterval? = nil,
        tokenTimings: [TimeInterval] = [],
        promptTokens: Int = 0,
        generatedTokens: Int = 0,
        totalTokens: Int = 0,
        contextWindowSize: Int? = nil,
        contextTokensUsed: Int? = nil,
        kvCacheBytes: Int64? = nil,
        kvCacheEntries: Int? = nil,
        tokenIds: [Int32] = [],
        tokenTexts: [String] = [],
        tokenLogProbs: [Float32] = [],
        tokenDurations: [TimeInterval] = [],
        stopReason: String? = nil,
        temperature: Float32? = nil,
        topP: Float32? = nil,
        topK: Int32? = nil,
        activeMemory: UInt64 = 0,
        cacheMemory: UInt64 = 0,
        peakMemory: UInt64 = 0,
        modelLoadTime: TimeInterval = 0,
        numParameters: Int = 0,
        perplexity: Double? = nil,
        entropy: Double? = nil,
        repetitionRate: Double? = nil,
        contextUtilization: Double? = nil,
        modelName: String? = nil,
        timeToFirstTokenP50: Double? = nil,
        timeToFirstTokenP95: Double? = nil,
        timeToFirstTokenP99: Double? = nil
    ) {
        self.totalTime = totalTime
        self.timeToFirstToken = timeToFirstToken
        self.timeSinceLastToken = timeSinceLastToken
        self.promptProcessingTime = promptProcessingTime
        self.tokenTimings = tokenTimings
        self.promptTokens = promptTokens
        self.generatedTokens = generatedTokens
        self.totalTokens = totalTokens
        self.contextWindowSize = contextWindowSize
        self.contextTokensUsed = contextTokensUsed
        self.kvCacheBytes = kvCacheBytes
        self.kvCacheEntries = kvCacheEntries
        self.tokenIds = tokenIds
        self.tokenTexts = tokenTexts
        self.tokenLogProbs = tokenLogProbs
        self.tokenDurations = tokenDurations
        self.stopReason = stopReason
        self.temperature = temperature
        self.topP = topP
        self.topK = topK
        self.activeMemory = activeMemory
        self.cacheMemory = cacheMemory
        self.peakMemory = peakMemory
        self.modelLoadTime = modelLoadTime
        self.numParameters = numParameters
        self.perplexity = perplexity
        self.entropy = entropy
        self.repetitionRate = repetitionRate
        self.contextUtilization = contextUtilization
        self.modelName = modelName
        self.timeToFirstTokenP50 = timeToFirstTokenP50
        self.timeToFirstTokenP95 = timeToFirstTokenP95
        self.timeToFirstTokenP99 = timeToFirstTokenP99
    }
}