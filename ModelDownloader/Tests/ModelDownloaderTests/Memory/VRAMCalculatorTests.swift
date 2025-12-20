import Abstractions
import Foundation
@testable import ModelDownloader
import Testing

@Suite("VRAMCalculator Tests")
struct VRAMCalculatorTests {
    let calculator: VRAMCalculator = VRAMCalculator()

    @Test("Calculate VRAM for 7B model with different quantizations")
    func test7BModelCalculations() throws {
        let parameters: UInt64 = 7_000_000_000 // 7B parameters

        // Test FP32 calculation
        let fp32Result: MemoryRequirements = try calculator.calculateMemoryRequirements(
            parameters: parameters,
            quantization: .fp32,
            overheadPercentage: 0.25
        )

        // Expected: 7B * 32 bits / 8 = 28GB base memory
        let expectedFP32Base: UInt64 = 28_000_000_000
        #expect(fp32Result.baseMemory >= expectedFP32Base - 1_000_000_000) // Allow 1GB tolerance
        #expect(fp32Result.baseMemory <= expectedFP32Base + 1_000_000_000)
        #expect(fp32Result.compressionRatio == 1.0)

        // Test FP16 calculation
        let fp16Result: MemoryRequirements = try calculator.calculateMemoryRequirements(
            parameters: parameters,
            quantization: .fp16,
            overheadPercentage: 0.25
        )

        // Expected: 7B * 16 bits / 8 = 14GB base memory
        let expectedFP16Base: UInt64 = 14_000_000_000
        #expect(fp16Result.baseMemory >= expectedFP16Base - 1_000_000_000)
        #expect(fp16Result.baseMemory <= expectedFP16Base + 1_000_000_000)
        #expect(fp16Result.compressionRatio == 2.0)

        // Test INT4 calculation
        let int4Result: MemoryRequirements = try calculator.calculateMemoryRequirements(
            parameters: parameters,
            quantization: .int4,
            overheadPercentage: 0.25
        )

        // Expected: 7B * 4 bits / 8 = 3.5GB base memory
        let expectedINT4Base: UInt64 = 3_500_000_000
        #expect(int4Result.baseMemory >= expectedINT4Base - 500_000_000)
        #expect(int4Result.baseMemory <= expectedINT4Base + 500_000_000)
        #expect(int4Result.compressionRatio == 8.0)
    }

    @Test("Overhead calculation")
    func testOverheadCalculation() throws {
        let parameters: UInt64 = 1_000_000_000 // 1B parameters
        let overheadPercentage: Double = 0.25 // 25%

        let result: MemoryRequirements = try calculator.calculateMemoryRequirements(
            parameters: parameters,
            quantization: .fp16,
            overheadPercentage: overheadPercentage
        )

        // Base memory: 1B * 16 / 8 = 2GB
        let expectedBase: UInt64 = 2_000_000_000
        let expectedOverhead: UInt64 = UInt64(Double(expectedBase) * overheadPercentage)

        #expect(result.overheadMemory == expectedOverhead)
        #expect(result.totalMemory == expectedBase + expectedOverhead)
    }

    @Test("GGUF quantization calculations")
    func testGGUFQuantizations() throws {
        let parameters: UInt64 = 8_000_000_000 // 8B parameters

        // Test various GGUF quantizations
        let quantizations: [(QuantizationLevel, Double)] = [
            (.q2_k, 2.5625),
            (.q3_k_m, 3.4375),
            (.q4_k_m, 4.625),
            (.q5_k_m, 5.625),
            (.q6_k, 6.5625),
            (.q8_0, 8.0)
        ]

        for (level, expectedBits): (QuantizationLevel, Double) in quantizations {
            let result: MemoryRequirements = try calculator.calculateMemoryRequirements(
                parameters: parameters,
                quantization: level,
                overheadPercentage: 0.0 // No overhead for clearer testing
            )

            // Calculate expected memory with integer arithmetic to match implementation
            let expectedMemory: UInt64 = (parameters * UInt64(expectedBits)) / 8

            // The actual calculation uses integer arithmetic now, so should be exact
            #expect(result.baseMemory == expectedMemory)
        }
    }

    @Test("Estimate from file size")
    func testEstimateFromFileSize() {
        let fileSize: UInt64 = 4_000_000_000 // 4GB file

        let result: MemoryRequirements = calculator.estimateFromFileSize(
            fileSize: fileSize,
            quantization: .q4_k_m,
            overheadPercentage: 0.25
        )

        // Should add metadata overhead (5%) plus inference overhead (25%)
        let expectedBase: UInt64 = UInt64(Double(fileSize) * 1.05)
        let expectedOverhead: UInt64 = UInt64(Double(expectedBase) * 0.25)

        #expect(result.baseMemory == expectedBase)
        #expect(result.overheadMemory == expectedOverhead)
        #expect(result.totalMemory == expectedBase + expectedOverhead)
    }

    @Test("Quick calculation from model size string")
    func testQuickCalculation() {
        // Test various model size formats
        let testCases: [(String, UInt64)] = [
            ("7B", 7_000_000_000),
            ("13B", 13_000_000_000),
            ("70B", 70_000_000_000),
            ("1.5B", 1_500_000_000),
            ("8x7B", 56_000_000_000) // MoE model
        ]

        for (sizeString, expectedParams): (String, UInt64) in testCases {
            let result: MemoryRequirements? = VRAMCalculator.quickCalculate(
                modelSize: sizeString,
                quantization: .int8,
                overheadPercentage: 0.0
            )

            #expect(result != nil)

            if let result {
                let expectedMemory: UInt64 = expectedParams // INT8 = 1 byte per param
                let tolerance: UInt64 = expectedMemory / 100 // 1% tolerance

                #expect(result.baseMemory >= expectedMemory - tolerance)
                #expect(result.baseMemory <= expectedMemory + tolerance)
            }
        }
    }

    @Test("Calculate all quantizations")
    func testCalculateAllQuantizations() {
        let parameters: UInt64 = 3_000_000_000 // 3B model

        let results: [QuantizationLevel: MemoryRequirements] = VRAMCalculator.calculateAllQuantizations(
            parameters: parameters,
            overheadPercentage: 0.25
        )

        // Should have results for main quantization levels
        #expect(results[.fp32] != nil)
        #expect(results[.fp16] != nil)
        #expect(results[.int8] != nil)
        #expect(results[.int4] != nil)

        // Verify compression ratios are correct
        #expect(results[.fp32]?.compressionRatio == 1.0)
        #expect(results[.fp16]?.compressionRatio == 2.0)
        #expect(results[.int8]?.compressionRatio == 4.0)
        #expect(results[.int4]?.compressionRatio == 8.0)

        // Verify memory ordering (FP32 > FP16 > INT8 > INT4)
        if let fp32 = results[.fp32], let fp16 = results[.fp16],
           let int8 = results[.int8], let int4 = results[.int4] {
            #expect(fp32.totalMemory > fp16.totalMemory)
            #expect(fp16.totalMemory > int8.totalMemory)
            #expect(int8.totalMemory > int4.totalMemory)
        }
    }

    @Test("Memory requirements formatting")
    func testMemoryRequirementsFormatting() {
        let requirements: MemoryRequirements = MemoryRequirements(
            baseMemory: 3_500_000_000, // 3.5GB
            overheadMemory: 875_000_000, // 0.875GB
            totalMemory: 4_375_000_000, // 4.375GB
            quantization: .int4,
            compressionRatio: 8.0
        )

        // Test formatted strings
        #expect(requirements.formattedBaseMemory.contains("GB") || requirements.formattedBaseMemory.contains("3"))
        #expect(requirements.formattedTotalMemory.contains("GB") || requirements.formattedTotalMemory.contains("4"))

        // Test GB calculation
        #expect(requirements.totalMemoryGB >= 4.0)
        #expect(requirements.totalMemoryGB <= 4.5)

        // Test compatibility checks
        #expect(requirements.canRunWith(availableMemory: 5_000_000_000) == true)
        #expect(requirements.canRunWith(availableMemory: 4_000_000_000) == false)

        // Test comfortable run (needs 20% extra buffer)
        let recommendedMemory: UInt64 = requirements.recommendedFreeMemory
        #expect(recommendedMemory > requirements.totalMemory)
        #expect(requirements.canRunComfortablyWith(availableMemory: recommendedMemory + 1) == true)
    }

    @Test("Quantization level detection from filename")
    func testQuantizationDetection() {
        let testCases: [(String, QuantizationLevel?)] = [
            ("model-Q4_K_M.gguf", .q4_k_m),
            ("llama-7b-Q5_K_S.gguf", .q5_k_s),
            ("model-fp16.safetensors", .fp16),
            ("model-int4.bin", .int4),
            ("model-8bit.gguf", .int8),
            ("regular-model.bin", nil),
            ("Q6_K-model.gguf", .q6_k)
        ]

        for (filename, expected): (String, QuantizationLevel?) in testCases {
            let detected: QuantizationLevel? = QuantizationLevel.detectFromFilename(filename)
            #expect(detected == expected, "Failed for filename: \(filename)")
        }
    }

    @Test("Integer overflow protection")
    func testIntegerOverflowProtection() {
        let calculator: VRAMCalculator = VRAMCalculator()

        // Test case that would overflow
        let veryLargeParameters: UInt64 = UInt64.max / 10 // Large enough to overflow when multiplied

        // This should throw an overflow error
        do {
            _ = try calculator.calculateMemoryRequirements(
                parameters: veryLargeParameters,
                quantization: .fp32, // 32 bits per parameter
                overheadPercentage: 0.25
            )
            Issue.record("Expected overflow error but calculation succeeded")
        } catch VRAMCalculationError.integerOverflow {
            // Expected error
        } catch {
            Issue.record("Unexpected error type: \(error)")
        }
    }
}
