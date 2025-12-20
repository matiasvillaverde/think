import Foundation

/// Represents device compatibility status for running a model
public enum DeviceCompatibility: Sendable, Equatable {
    /// Model can run with full GPU offload
    case fullGPUOffload(availableMemory: UInt64)

    /// Model can run with partial GPU offload
    case partialGPUOffload(percentageOffloaded: Double, availableMemory: UInt64)

    /// Model can run but is not recommended
    case notRecommended(reason: String)

    /// Model cannot run on this device
    case incompatible(minimumRequired: UInt64, available: UInt64)

    /// Compatibility status message
    public var statusMessage: String {
        switch self {
        case .fullGPUOffload:
            return "This model will run smoothly on your device"
        case .partialGPUOffload(let percentage, _):
            return "This model will run well (using \(Int(percentage))% of available performance)"
        case .notRecommended(let reason):
            return "This model may run slowly. \(reason)"
        case .incompatible:
            return "This model is too large for your device"
        }
    }

    /// Whether the model can run at all
    public var canRun: Bool {
        switch self {
        case .fullGPUOffload, .partialGPUOffload:
            return true
        case .notRecommended:
            return true // Can run, just not recommended
        case .incompatible:
            return false
        }
    }

    /// Quality level (1.0 = best, 0.0 = worst)
    public var qualityLevel: Double {
        switch self {
        case .fullGPUOffload:
            return 1.0
        case .partialGPUOffload(let percentage, _):
            return 0.5 + (percentage / 200.0) // 50-100% based on offload percentage
        case .notRecommended:
            return 0.3
        case .incompatible:
            return 0.0
        }
    }
}
