import Foundation
import Abstractions

/// Mock implementation of DeviceCompatibilityProtocol for testing
public final class MockDeviceCompatibilityChecker: DeviceCompatibilityProtocol, @unchecked Sendable {
    public var memoryInfo = DeviceMemoryInfo(
        totalMemory: 16_000_000_000,
        availableMemory: 12_000_000_000,
        usedMemory: 4_000_000_000,
        platform: .macOS,
        hasUnifiedMemory: true
    )

    public var compatibilityResult: DeviceCompatibility = .fullGPUOffload(availableMemory: 16_000_000_000)
    public var compatibilityResults: [UInt64: DeviceCompatibility] = [:]

    public init() {
        // Empty initializer for mock
    }

    public func checkCompatibility(for requirements: MemoryRequirements) -> DeviceCompatibility {
        if let result = compatibilityResults[requirements.totalMemory] {
            return result
        }
        return compatibilityResult
    }

    public func getDeviceMemoryInfo() -> DeviceMemoryInfo {
        memoryInfo
    }
}
