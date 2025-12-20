import Foundation

/// Protocol for calculating VRAM requirements for AI models
///
/// This protocol defines the interface for calculating memory requirements
/// based on model parameters and quantization levels. Implementations should
/// provide accurate calculations with platform-specific considerations.
///
/// ## Example Usage
/// ```swift
/// let calculator: VRAMCalculatorProtocol = VRAMCalculator()
/// do {
///     let requirements = try calculator.calculateMemoryRequirements(
///         parameters: 7_000_000_000, // 7B parameters
///         quantization: .int4,
///         overheadPercentage: 0.25
///     )
///     print("VRAM needed: \(requirements.vramRequired) bytes")
/// } catch {
///     print("Error calculating VRAM: \(error)")
/// }
/// ```
public protocol VRAMCalculatorProtocol: Sendable {
    /// Calculate memory requirements for a model
    /// - Parameters:
    ///   - parameters: Number of model parameters
    ///   - quantization: Quantization level
    ///   - overheadPercentage: Additional overhead for inference (default: 0.25 for 25%)
    /// - Returns: Detailed memory requirements
    /// - Throws: Error if calculation would result in integer overflow
    func calculateMemoryRequirements(
        parameters: UInt64,
        quantization: QuantizationLevel,
        overheadPercentage: Double
    ) throws -> MemoryRequirements

    /// Calculate memory requirements from file size (for models without parameter info)
    /// - Parameters:
    ///   - fileSize: Size of model files in bytes
    ///   - quantization: Detected or assumed quantization level
    ///   - overheadPercentage: Additional overhead for inference
    /// - Returns: Estimated memory requirements
    func estimateFromFileSize(
        fileSize: UInt64,
        quantization: QuantizationLevel,
        overheadPercentage: Double
    ) -> MemoryRequirements
}
