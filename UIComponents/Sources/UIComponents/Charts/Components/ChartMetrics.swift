import Database
import Foundation

/// Protocol defining the metrics data required by chart components
public protocol ChartMetrics {
    /// Creation timestamp for the metrics
    var createdAt: Date { get }
    /// Total time for the operation
    var totalTime: TimeInterval { get }
    /// Number of tokens in the prompt
    var promptTokens: Int { get }
    /// Number of generated tokens
    var generatedTokens: Int { get }
    /// Total token count
    var totalTokens: Int { get }

    // Memory metrics
    /// Active memory usage in bytes
    var activeMemory: UInt64 { get }
    /// Peak memory usage in bytes
    var peakMemory: UInt64 { get }

    // Optional advanced metrics
    /// Perplexity measure of model confidence
    var perplexity: Double? { get }
    /// Entropy measure of randomness
    var entropy: Double? { get }
    /// Rate of token repetition
    var repetitionRate: Double? { get }
    /// Percentage of context window used
    var contextUtilization: Double? { get }

    // Performance metrics
    /// Tokens generated per second
    var tokensPerSecond: Double { get }
    /// Name of the model used
    var modelName: String? { get }
}

// Make Metrics conform to ChartMetrics
extension Metrics: ChartMetrics {
    // All properties already exist in Metrics, no implementation needed
}
