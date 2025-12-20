import Abstractions
import Foundation
import OSLog

/// Errors that can occur during VRAM calculation
public enum VRAMCalculationError: Error {
    case integerOverflow(String)
}

/// Default implementation of VRAMCalculatorProtocol
///
/// Provides accurate VRAM calculations based on model parameters
/// and quantization levels, with support for various quantization schemes.
public struct VRAMCalculator: VRAMCalculatorProtocol {
    private let logger: Logger = Logger(subsystem: "ModelDownloader", category: "VRAMCalculator")

    public init() {}

    /// Calculate memory requirements for a model
    public func calculateMemoryRequirements(
        parameters: UInt64,
        quantization: QuantizationLevel,
        overheadPercentage: Double = 0.25
    ) throws -> MemoryRequirements {
        logger.debug(
            "Calculating memory requirements for \(parameters) parameters with \(quantization.rawValue) quantization"
        )

        // Calculate base memory: (parameters × bits per parameter) / 8 (bits to bytes)
        let bitsPerParameter: Double = quantization.bitsPerParameter

        // Use checked arithmetic to prevent overflow
        let (parameterBits, overflow1): (UInt64, Bool) = parameters.multipliedReportingOverflow(
            by: UInt64(bitsPerParameter)
        )
        guard !overflow1 else {
            let error: VRAMCalculationError = VRAMCalculationError.integerOverflow(
                "Parameter count (\(parameters)) × bits per parameter (\(bitsPerParameter)) would overflow"
            )
            logger.error("VRAM calculation failed: \(error.localizedDescription)")
            throw error
        }

        // Convert bits to bytes
        let baseMemoryBytes: UInt64 = parameterBits / 8

        // Calculate overhead with overflow checking
        let overheadMultiplier: Double = 1.0 + overheadPercentage
        let totalMemoryDouble: Double = Double(baseMemoryBytes) * overheadMultiplier

        // Check if the result can fit in UInt64
        guard totalMemoryDouble <= Double(UInt64.max) else {
            let error: VRAMCalculationError = VRAMCalculationError.integerOverflow(
                "Total memory calculation (\(totalMemoryDouble) bytes) exceeds UInt64 maximum"
            )
            logger.error("VRAM calculation failed: \(error.localizedDescription)")
            throw error
        }

        let overheadBytes: UInt64 = UInt64(Double(baseMemoryBytes) * overheadPercentage)
        let totalMemory: UInt64 = baseMemoryBytes + overheadBytes

        // Compression ratio compared to FP32
        let compressionRatio: Double = 32.0 / bitsPerParameter

        let requirements: MemoryRequirements = MemoryRequirements(
            baseMemory: baseMemoryBytes,
            overheadMemory: overheadBytes,
            totalMemory: totalMemory,
            quantization: quantization,
            compressionRatio: compressionRatio
        )

        logger.info(
            """
            Calculated memory requirements: base=\(baseMemoryBytes) bytes, \
            overhead=\(overheadBytes) bytes, total=\(totalMemory) bytes
            """
        )

        return requirements
    }

    /// Estimate memory requirements from file size
    public func estimateFromFileSize(
        fileSize: UInt64,
        quantization: QuantizationLevel,
        overheadPercentage: Double = 0.25
    ) -> MemoryRequirements {
        // For most models, file size is close to the actual memory needed
        // Add a small buffer for metadata and structure overhead
        let metadataOverhead: Double = 1.05 // 5% for metadata
        let baseMemory: UInt64 = UInt64(Double(fileSize) * metadataOverhead)

        // Calculate inference overhead
        let overheadMemory: UInt64 = UInt64(Double(baseMemory) * overheadPercentage)

        // Total memory
        let totalMemory: UInt64 = baseMemory + overheadMemory

        // Compression ratio is approximate when estimating from file size
        let compressionRatio: Double = 32.0 / quantization.bitsPerParameter

        return MemoryRequirements(
            baseMemory: baseMemory,
            overheadMemory: overheadMemory,
            totalMemory: totalMemory,
            quantization: quantization,
            compressionRatio: compressionRatio
        )
    }

    // MARK: - Static Calculation Methods

    /// Quick calculation for common model sizes
    /// - Parameters:
    ///   - modelSize: Common model size string (e.g., "7B", "13B", "70B")
    ///   - quantization: Quantization level
    ///   - overheadPercentage: Overhead percentage
    /// - Returns: Memory requirements or nil if size not recognized
    public static func quickCalculate(
        modelSize: String,
        quantization: QuantizationLevel,
        overheadPercentage: Double = 0.25
    ) -> MemoryRequirements? {
        guard let parameters = ModelParameters.fromString(modelSize) else {
            return nil
        }

        let calculator: Self = Self()
        return try? calculator.calculateMemoryRequirements(
            parameters: parameters.count,
            quantization: quantization,
            overheadPercentage: overheadPercentage
        )
    }

    /// Calculate memory for all common quantizations
    /// - Parameters:
    ///   - parameters: Number of parameters
    ///   - overheadPercentage: Overhead percentage
    /// - Returns: Dictionary of quantization level to memory requirements
    public static func calculateAllQuantizations(
        parameters: UInt64,
        overheadPercentage: Double = 0.25
    ) -> [QuantizationLevel: MemoryRequirements] {
        let calculator: Self = Self()
        var results: [QuantizationLevel: MemoryRequirements] = [QuantizationLevel: MemoryRequirements]()

        // Calculate for main quantization levels
        let mainLevels: [QuantizationLevel] = [.fp32, .fp16, .int8, .int4]

        for level in mainLevels {
            if let requirements = try? calculator.calculateMemoryRequirements(
                parameters: parameters,
                quantization: level,
                overheadPercentage: overheadPercentage
            ) {
                results[level] = requirements
            }
        }

        return results
    }
}
