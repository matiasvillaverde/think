import Foundation

/// Model parameter information for AI models
///
/// Encapsulates information about the number of parameters in a model,
/// including both raw counts and human-readable formatting. Supports
/// standard models as well as Mixture of Experts (MoE) architectures.
///
/// ## Examples
/// ```swift
/// // Standard 7B parameter model
/// let llama7B = ModelParameters(count: 7_000_000_000, formatted: "7B")
/// 
/// // Mixture of Experts model (8 experts × 7B each)
/// let mixtral = ModelParameters(
///     count: 56_000_000_000, 
///     formatted: "8x7B", 
///     isMixtureOfExperts: true
/// )
/// 
/// // Parse from string
/// let params = ModelParameters.fromString("70B") // Creates 70B parameter model
/// ```
public struct ModelParameters: Sendable, Codable, Equatable, Hashable {
    /// Raw parameter count as unsigned 64-bit integer
    public let count: UInt64

    /// Human-readable format (e.g., "7B", "70B", "8x7B")
    ///
    /// Standard formatting conventions:
    /// - "B" suffix for billions of parameters
    /// - "x" separator for MoE models (e.g., "8x7B" = 8 experts × 7B each)
    /// - Preserves original capitalization and format
    public let formatted: String

    /// Whether this represents a mixture of experts model
    ///
    /// MoE models have multiple expert networks that are selectively activated,
    /// allowing for larger total parameter counts with efficient inference.
    public let isMixtureOfExperts: Bool

    /// Initialize model parameters
    /// - Parameters:
    ///   - count: Raw parameter count
    ///   - formatted: Human-readable string representation
    ///   - isMixtureOfExperts: Whether this is an MoE model
    public init(count: UInt64, formatted: String, isMixtureOfExperts: Bool = false) {
        self.count = count
        self.formatted = formatted
        self.isMixtureOfExperts = isMixtureOfExperts
    }

    /// Create ModelParameters from a string representation
    ///
    /// Parses common model size formats and returns the corresponding ModelParameters.
    /// Supports both standard models (e.g., "7B", "70B") and MoE models (e.g., "8x7B").
    ///
    /// - Parameter string: String representation like "7B", "70B", or "8x7B"
    /// - Returns: ModelParameters instance, or nil if parsing fails
    ///
    /// ## Supported Formats
    /// - **Standard**: "7B", "13B", "70B" (with or without "B" suffix)
    /// - **MoE**: "8x7B", "2x3B" (expert_count × expert_size format)
    /// - **Case insensitive**: "7b", "7B", "7" all work
    public static func fromString(_ string: String) -> ModelParameters? {
        let normalized = string.uppercased().trimmingCharacters(in: .whitespaces)

        // Handle MoE models (e.g., "8x7B")
        if normalized.contains("X") {
            let components = normalized.split(separator: "X")
            if components.count == 2,
               let experts = UInt64(components[0]),
               let size = parseSize(String(components[1])) {
                let totalParams = experts * size
                return ModelParameters(
                    count: totalParams,
                    formatted: normalized,
                    isMixtureOfExperts: true
                )
            }
        }

        // Handle standard models
        if let count = parseSize(normalized) {
            return ModelParameters(count: count, formatted: normalized)
        }

        return nil
    }

    /// Parse parameter size from string (e.g., "7B" → 7_000_000_000)
    private static func parseSize(_ string: String) -> UInt64? {
        let cleanString = string.replacingOccurrences(of: "B", with: "")
        guard let value = Double(cleanString) else {
            return nil
        }

        // Validate input bounds - reasonable model sizes are between 0.1B and 10000B parameters
        guard value > 0, value <= 10_000 else {
            return nil
        }

        // Check for overflow before multiplication
        let billion: Double = 1_000_000_000
        let result = value * billion

        // Ensure result fits in UInt64
        guard result <= Double(UInt64.max) else {
            return nil
        }

        return UInt64(result)
    }
}
