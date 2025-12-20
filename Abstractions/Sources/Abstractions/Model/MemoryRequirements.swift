import Foundation

/// Detailed memory requirements for running an AI model
///
/// This structure provides comprehensive memory requirement information
/// including VRAM needed, overhead calculations, and platform-specific details.
///
/// ## Example
/// ```swift
/// let requirements = MemoryRequirements(
///     baseMemory: 3_435_973_836, // ~3.2GB
///     overheadMemory: 858_993_459, // ~0.8GB (25% overhead)
///     totalMemory: 4_294_967_296, // ~4GB total
///     quantization: .int4,
///     compressionRatio: 8.0
/// )
/// ```
@DebugDescription
public struct MemoryRequirements: Equatable, Hashable, Sendable, Codable {
    /// Base memory required for model weights (in bytes)
    public let baseMemory: UInt64

    /// Additional memory for inference overhead (in bytes)
    public let overheadMemory: UInt64

    /// Total memory required (base + overhead) in bytes
    public let totalMemory: UInt64

    /// Quantization level used for calculation
    public let quantization: QuantizationLevel

    /// Compression ratio compared to FP32
    public let compressionRatio: Double

    /// Minimum free memory recommended for smooth operation
    public var recommendedFreeMemory: UInt64 {
        // Add 20% buffer on top of total memory
        UInt64(Double(totalMemory) * 1.2)
    }

    /// Initialize memory requirements
    public init(
        baseMemory: UInt64,
        overheadMemory: UInt64,
        totalMemory: UInt64,
        quantization: QuantizationLevel,
        compressionRatio: Double
    ) {
        self.baseMemory = baseMemory
        self.overheadMemory = overheadMemory
        self.totalMemory = totalMemory
        self.quantization = quantization
        self.compressionRatio = compressionRatio
    }
}

// MARK: - Formatted Properties

public extension MemoryRequirements {
    /// Formatted base memory string
    var formattedBaseMemory: String {
        ByteCountFormatter.string(fromByteCount: Int64(baseMemory), countStyle: .memory)
    }

    /// Formatted overhead memory string
    var formattedOverheadMemory: String {
        ByteCountFormatter.string(fromByteCount: Int64(overheadMemory), countStyle: .memory)
    }

    /// Formatted total memory string
    var formattedTotalMemory: String {
        ByteCountFormatter.string(fromByteCount: Int64(totalMemory), countStyle: .memory)
    }

    /// Formatted recommended free memory string
    var formattedRecommendedMemory: String {
        ByteCountFormatter.string(fromByteCount: Int64(recommendedFreeMemory), countStyle: .memory)
    }

    /// Get memory in gigabytes
    var totalMemoryGB: Double {
        Double(totalMemory) / pow(1024, 3)
    }
}

// MARK: - Comparison Helpers

public extension MemoryRequirements {
    /// Check if these requirements can be satisfied with available memory
    /// - Parameter availableMemory: Available memory in bytes
    /// - Returns: True if model can run with available memory
    func canRunWith(availableMemory: UInt64) -> Bool {
        totalMemory <= availableMemory
    }

    /// Check if these requirements can run comfortably with available memory
    /// - Parameter availableMemory: Available memory in bytes
    /// - Returns: True if model can run comfortably (with recommended buffer)
    func canRunComfortablyWith(availableMemory: UInt64) -> Bool {
        recommendedFreeMemory <= availableMemory
    }

    /// Calculate percentage of available memory that will be used
    /// - Parameter availableMemory: Available memory in bytes
    /// - Returns: Percentage (0-100) of memory that will be used
    func memoryUsagePercentage(availableMemory: UInt64) -> Double {
        guard availableMemory > 0 else {
            return 100.0
        }
        return (Double(totalMemory) / Double(availableMemory)) * 100.0
    }
}
