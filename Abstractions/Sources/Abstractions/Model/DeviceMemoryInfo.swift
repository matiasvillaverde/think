import Foundation

/// Device memory information
public struct DeviceMemoryInfo: Sendable, Equatable {
    /// Total physical memory in bytes
    public let totalMemory: UInt64

    /// Currently available memory in bytes
    public let availableMemory: UInt64

    /// Memory used by other processes
    public let usedMemory: UInt64

    /// Platform type (macOS, iOS, iPadOS, visionOS)
    public let platform: Platform

    /// Whether device has unified memory architecture
    public let hasUnifiedMemory: Bool

    /// GPU-specific memory (if separate from system memory)
    public let dedicatedGPUMemory: UInt64?

    /// Neural Engine memory capacity (if available)
    public let neuralEngineCapable: Bool

    public init(
        totalMemory: UInt64,
        availableMemory: UInt64,
        usedMemory: UInt64,
        platform: Platform,
        hasUnifiedMemory: Bool,
        dedicatedGPUMemory: UInt64? = nil,
        neuralEngineCapable: Bool = false
    ) {
        self.totalMemory = totalMemory
        self.availableMemory = availableMemory
        self.usedMemory = usedMemory
        self.platform = platform
        self.hasUnifiedMemory = hasUnifiedMemory
        self.dedicatedGPUMemory = dedicatedGPUMemory
        self.neuralEngineCapable = neuralEngineCapable
    }

    /// Platform enumeration
    public enum Platform: String, Sendable, Codable {
        case macOS = "macOS"
        case iOS = "iOS"
        case iPadOS = "iPadOS"
        case visionOS = "visionOS"

        /// Minimum recommended memory for this platform
        public var minimumRecommendedMemory: UInt64 {
            switch self {
            case .macOS:
                return 8 * 1024 * 1024 * 1024 // 8GB
            case .iOS, .iPadOS:
                return 4 * 1024 * 1024 * 1024 // 4GB
            case .visionOS:
                return 6 * 1024 * 1024 * 1024 // 6GB
            }
        }
    }
}

// MARK: - Formatted Properties

public extension DeviceMemoryInfo {
    /// Formatted total memory
    var formattedTotalMemory: String {
        ByteCountFormatter.string(fromByteCount: Int64(totalMemory), countStyle: .memory)
    }

    /// Formatted available memory
    var formattedAvailableMemory: String {
        ByteCountFormatter.string(fromByteCount: Int64(availableMemory), countStyle: .memory)
    }

    /// Memory usage percentage
    var memoryUsagePercentage: Double {
        guard totalMemory > 0 else {
            return 0
        }
        return (Double(usedMemory) / Double(totalMemory)) * 100.0
    }
}
