/// Parameters controlling text generation randomness and quality.
///
/// These parameters affect how the model selects tokens during generation.
/// Finding the right balance is crucial for output quality - too low and the
/// model becomes repetitive, too high and it becomes incoherent.
public struct SamplingParameters: Sendable {
    /// Controls randomness in token selection (0.0 to 2.0).
    ///
    /// - 0.0: Deterministic (always picks most likely token)
    /// - 0.7: Balanced creativity (good default)
    /// - 1.0: Neutral (uses model's learned distribution)
    /// - 2.0: Very creative (may be incoherent)
    public let temperature: Float

    /// Nucleus sampling threshold (0.0 to 1.0).
    ///
    /// Only considers tokens whose cumulative probability exceeds this threshold.
    /// For example, 0.9 means "only consider the most likely tokens that together
    /// have 90% probability mass". This provides a dynamic way to limit choices
    /// to plausible options.
    ///
    /// - Note: Generally, adjust either temperature OR topP, not both.
    public let topP: Float

    /// Limits token selection to the K most likely tokens.
    ///
    /// Unlike topP, this is a hard cutoff. For example, topK=50 means the model
    /// can only choose from the 50 most likely next tokens. This can help prevent
    /// the model from selecting extremely unlikely tokens.
    ///
    /// Set to nil to disable topK filtering.
    public let topK: Int?

    /// Penalty applied to tokens based on their frequency in the output.
    ///
    /// Values > 1.0 discourage repetition, < 1.0 encourage it.
    /// Typical range is 1.0 to 1.2 for reducing repetitive text.
    public let repetitionPenalty: Float?

    /// Penalty based on the frequency of tokens in the generated text.
    ///
    /// Positive values (0.0 to 2.0) reduce the likelihood of repeating tokens
    /// proportionally to how often they've appeared. Unlike repetition penalty,
    /// this scales with frequency count.
    public let frequencyPenalty: Float?

    /// Penalty for tokens that have appeared at least once.
    ///
    /// Positive values (0.0 to 2.0) discourage any repetition by applying
    /// a flat penalty to all tokens that have appeared, regardless of frequency.
    public let presencePenalty: Float?

    /// Number of tokens to look back for applying penalties.
    ///
    /// Determines the context window for repetition, frequency, and presence
    /// penalties. Smaller values (32-64) focus on recent context, larger values
    /// (128-512) consider more history. Default is typically 64.
    public let repetitionPenaltyRange: Int?

    /// Random seed for reproducible generation.
    ///
    /// When set, the provider should attempt deterministic generation.
    /// Note that true determinism may not be possible with all providers
    /// or in all conditions (e.g., with parallel processing).
    public let seed: Int?

    /// Sequences that immediately stop generation when produced.
    ///
    /// Common examples:
    /// - ["</response>"] for XML-style outputs
    /// - ["\n\n"] to stop at double newline
    /// - ["User:", "Human:"] to stop before the next turn
    public let stopSequences: [String]

    /// Default sampling parameters providing balanced generation.
    public static let `default` = SamplingParameters(
        temperature: 0.7,
        topP: 0.9,
        topK: nil,
        repetitionPenalty: nil,
        seed: nil,
        stopSequences: []
    )

    /// Deterministic sampling for reproducible outputs.
    public static let deterministic = SamplingParameters(
        temperature: 0.0,
        topP: 1.0,
        topK: 1,
        repetitionPenalty: nil,
        seed: 42,
        stopSequences: []
    )

    /// Creative sampling for varied, interesting outputs.
    public static let creative = SamplingParameters(
        temperature: 1.2,
        topP: 0.95,
        topK: nil,
        repetitionPenalty: 1.1,
        seed: nil,
        stopSequences: []
    )

    /// Creates new sampling parameters for controlling text generation.
    ///
    /// - Parameters:
    ///   - temperature: Controls randomness in token selection (0.0 to 2.0)
    ///   - topP: Nucleus sampling threshold (0.0 to 1.0)
    ///   - topK: Limits token selection to the K most likely tokens (nil to disable)
    ///   - repetitionPenalty: Penalty applied to tokens based on frequency (nil to disable)
    ///   - frequencyPenalty: Penalty proportional to token frequency (nil to disable)
    ///   - presencePenalty: Flat penalty for any repeated tokens (nil to disable)
    ///   - repetitionPenaltyRange: Number of tokens to look back for penalties (nil for default)
    ///   - seed: Random seed for reproducible generation (nil for non-deterministic)
    ///   - stopSequences: Sequences that immediately stop generation when produced
    public init(
        temperature: Float,
        topP: Float,
        topK: Int? = nil,
        repetitionPenalty: Float? = nil,
        frequencyPenalty: Float? = nil,
        presencePenalty: Float? = nil,
        repetitionPenaltyRange: Int? = nil,
        seed: Int? = nil,
        stopSequences: [String] = []
    ) {
        self.temperature = temperature
        self.topP = topP
        self.topK = topK
        self.repetitionPenalty = repetitionPenalty
        self.frequencyPenalty = frequencyPenalty
        self.presencePenalty = presencePenalty
        self.repetitionPenaltyRange = repetitionPenaltyRange
        self.seed = seed
        self.stopSequences = stopSequences
    }
}
