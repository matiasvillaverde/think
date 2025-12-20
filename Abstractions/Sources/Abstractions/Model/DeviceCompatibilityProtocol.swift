import Foundation

/// Protocol for checking device compatibility with AI models
///
/// This protocol defines the interface for determining whether a model
/// can run on the current device, with detailed compatibility information
/// and platform-specific considerations.
///
/// ## Example Usage
/// ```swift
/// let checker: DeviceCompatibilityProtocol = DeviceCompatibilityChecker()
/// let compatibility = await checker.checkCompatibility(for: memoryRequirements)
/// 
/// switch compatibility {
/// case .fullGPUOffload(let available):
///     print("Model can run with full GPU offload. Available: \(available)")
/// case .partialGPUOffload(let percentage):
///     print("Model can run with \(percentage)% GPU offload")
/// case .notRecommended(let reason):
///     print("Not recommended: \(reason)")
/// case .incompatible(let required, let available):
///     print("Incompatible. Need: \(required), Have: \(available)")
/// }
/// ```
public protocol DeviceCompatibilityProtocol: Sendable {
    /// Check compatibility for given memory requirements
    /// - Parameter requirements: Memory requirements to check
    /// - Returns: Detailed compatibility status
    func checkCompatibility(for requirements: MemoryRequirements) async -> DeviceCompatibility

    /// Get current device memory information
    /// - Returns: Device memory status
    func getDeviceMemoryInfo() async -> DeviceMemoryInfo
}
