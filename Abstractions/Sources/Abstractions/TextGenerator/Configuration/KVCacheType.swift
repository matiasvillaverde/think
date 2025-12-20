import Foundation

/// Type of quantization to use for KV cache storage
/// This affects memory usage and performance
public enum KVCacheType: String, Sendable, CaseIterable {
    /// 32-bit floating point (highest quality, most memory)
    case f32 = "F32"

    /// 16-bit floating point (good quality, moderate memory)
    case f16 = "F16"

    /// 8-bit quantized (balanced quality/memory)
    case q8_0 = "Q8_0"

    /// 4-bit quantized (lower quality, least memory)
    case q4_0 = "Q4_0"

    /// Default type for most use cases
    public static let `default`: KVCacheType = .f16

    /// Recommended type for iOS/mobile devices
    public static let mobile: KVCacheType = .q8_0

    /// Recommended type for high quality on desktop
    public static let desktop: KVCacheType = .f16
}
