import Foundation

/// Detailed generation quality and performance metrics.
///
/// Provides fine-grained information about the generation process,
/// including per-token data and quality indicators.
public struct GenerationMetrics: Sendable, Codable {
    /// Reason why generation stopped.
    public enum StopReason: String, Sendable, Codable {
        /// Reached maximum token limit
        case maxTokens = "max_tokens"
        /// Encountered a stop sequence
        case stopSequence = "stop_sequence"
        /// Generated end-of-sequence token
        case endOfSequence = "end_of_sequence"
        /// User requested stop
        case userRequested = "user_requested"
        /// Generation timed out
        case timeout = "timeout"
        /// An error occurred
        case error = "error"
    }

    /// Detailed information about a single generated token.
    public struct TokenInfo: Sendable, Codable {
        /// The token ID in the model's vocabulary
        public let tokenId: Int32

        /// The decoded text representation of the token
        public let text: String

        /// Log probability of this token being selected
        public let logProb: Float32

        /// Time taken to generate this specific token
        public let duration: Duration

        /// Creates new token information.
        ///
        /// - Parameters:
        ///   - tokenId: The token ID in the model's vocabulary
        ///   - text: The decoded text representation
        ///   - logProb: Log probability of selection
        ///   - duration: Time to generate this token
        public init(
            tokenId: Int32,
            text: String,
            logProb: Float32,
            duration: Duration
        ) {
            self.tokenId = tokenId
            self.text = text
            self.logProb = logProb
            self.duration = duration
        }
    }

    /// Detailed information about each generated token.
    ///
    /// This array contains rich data for each token, enabling detailed
    /// analysis of generation quality, performance, and behavior.
    public let tokens: [TokenInfo]

    /// The reason generation stopped.
    ///
    /// Useful for understanding whether generation completed naturally
    /// or was interrupted by limits, errors, or user action.
    public let stopReason: StopReason?

    /// Temperature setting used for generation.
    ///
    /// Higher values produce more random output, lower values are more deterministic.
    public let temperature: Float32?

    /// Top-p (nucleus sampling) setting used.
    ///
    /// Cumulative probability cutoff for token selection.
    public let topP: Float32?

    /// Top-k setting used for generation.
    ///
    /// Number of top tokens considered at each step.
    public let topK: Int32?

    /// Creates new generation metrics.
    ///
    /// - Parameters:
    ///   - tokens: Optional array of detailed token information
    ///   - stopReason: Optional reason for stopping
    ///   - temperature: Optional temperature setting
    ///   - topP: Optional top-p setting
    ///   - topK: Optional top-k setting
    public init(
        tokens: [TokenInfo] = [],
        stopReason: StopReason? = nil,
        temperature: Float32? = nil,
        topP: Float32? = nil,
        topK: Int32? = nil
    ) {
        self.tokens = tokens
        self.stopReason = stopReason
        self.temperature = temperature
        self.topP = topP
        self.topK = topK
    }
}

// MARK: - Computed Properties

extension GenerationMetrics {
    /// Calculate perplexity from token log probabilities.
    ///
    /// Lower perplexity indicates the model is more confident in its predictions.
    /// Perplexity = exp(average negative log likelihood)
    public var perplexity: Double? {
        guard !tokens.isEmpty else {
            return nil
        }

        let sumNegLogProb = tokens.reduce(0.0) { sum, token in
            sum - Double(token.logProb)
        }
        let avgNegLogProb = sumNegLogProb / Double(tokens.count)
        return exp(avgNegLogProb)
    }

    /// Calculate the repetition rate in generated tokens.
    ///
    /// Returns the percentage of tokens that are repeated within a window.
    /// - Parameter windowSize: Size of the sliding window for repetition detection
    /// - Returns: Repetition rate as a percentage (0.0 to 1.0)
    public func repetitionRate(windowSize: Int = 20) -> Double? {
        guard tokens.count > windowSize else {
            return nil
        }

        var repetitions = 0
        var totalChecks = 0

        for i in windowSize..<tokens.count {
            let currentToken = tokens[i].tokenId
            let window = tokens[(i - windowSize)..<i]

            if window.contains(where: { $0.tokenId == currentToken }) {
                repetitions += 1
            }
            totalChecks += 1
        }

        return totalChecks > 0 ? Double(repetitions) / Double(totalChecks) : nil
    }

    /// Average log probability across all tokens.
    ///
    /// Higher values indicate more confident generation.
    public var averageLogProb: Float32? {
        guard !tokens.isEmpty else {
            return nil
        }

        let sum = tokens.reduce(Float32(0)) { sum, token in
            sum + token.logProb
        }
        return sum / Float32(tokens.count)
    }

    /// Entropy of the token distribution.
    ///
    /// Higher entropy indicates more diverse/random generation.
    public var entropy: Double? {
        guard !tokens.isEmpty else {
            return nil
        }

        // Calculate entropy from log probabilities
        let entropy = tokens.reduce(0.0) { sum, token in
            let prob = exp(Double(token.logProb))
            return sum - (prob * Double(token.logProb))
        }
        return entropy / Double(tokens.count)
    }

    /// Total text generated by concatenating all tokens.
    public var generatedText: String? {
        guard !tokens.isEmpty else {
            return nil
        }
        return tokens.map(\.text).joined()
    }
}
