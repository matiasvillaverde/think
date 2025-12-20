import Foundation

/// RoPE (Rotary Position Embedding) scaling type for extended context
public enum RopeScalingType: String, Sendable, CaseIterable {
    /// No scaling (default)
    case noScaling = "None"

    /// Linear scaling for extended context
    case linear = "Linear"

    /// YaRN (Yet another RoPE extension) scaling
    case yarn = "YaRN"

    /// Default scaling type
    public static let `default`: RopeScalingType = .noScaling
}
