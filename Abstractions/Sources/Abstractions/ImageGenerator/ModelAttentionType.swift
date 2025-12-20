import Foundation

/// Model attention type configuration for Core ML models
public enum ModelAttentionType: String, Sendable {
    /// Automatically detect from model metadata
    case automatic = "Automatic"

    /// Force split einsum attention (better for larger images)
    case splitEinsum = "SplitEinsum"

    /// Force original attention (better for smaller images)
    case original = "Original"
}
