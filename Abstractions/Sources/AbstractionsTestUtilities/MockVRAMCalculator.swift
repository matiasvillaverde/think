import Foundation
import Abstractions

/// Mock implementation of VRAMCalculatorProtocol for testing
public final class MockVRAMCalculator: VRAMCalculatorProtocol, @unchecked Sendable {
    /// Set to true to throw an error from calculateMemoryRequirements
    public var shouldThrowError = false

    /// Custom result to return from estimateFromFileSize
    public var estimateResult: MemoryRequirements?

    public init() {
        // Empty initializer for mock
    }

    public func calculateMemoryRequirements(
        parameters: UInt64,
        quantization: QuantizationLevel,
        overheadPercentage: Double
    ) throws -> MemoryRequirements {
        if shouldThrowError {
            throw MockVRAMCalculationError.integerOverflow("Mock overflow error for testing")
        }

        let baseMemory = UInt64(Double(parameters) * quantization.bitsPerParameter / 8.0)
        let overheadMemory = UInt64(Double(baseMemory) * overheadPercentage)
        return MemoryRequirements(
            baseMemory: baseMemory,
            overheadMemory: overheadMemory,
            totalMemory: baseMemory + overheadMemory,
            quantization: quantization,
            compressionRatio: 32.0 / quantization.bitsPerParameter
        )
    }

    public func estimateFromFileSize(
        fileSize: UInt64,
        quantization: QuantizationLevel,
        overheadPercentage: Double
    ) -> MemoryRequirements {
        if let customResult = estimateResult {
            return customResult
        }

        let baseMemory = fileSize
        let overheadMemory = UInt64(Double(baseMemory) * overheadPercentage)
        return MemoryRequirements(
            baseMemory: baseMemory,
            overheadMemory: overheadMemory,
            totalMemory: baseMemory + overheadMemory,
            quantization: quantization,
            compressionRatio: 32.0 / quantization.bitsPerParameter
        )
    }
}
