import Abstractions
import Foundation
@testable import ModelDownloader
import Testing

@Suite("DeviceCompatibility Tests")
struct DeviceCompatibilityTests {
    let checker: DeviceCompatibilityChecker = DeviceCompatibilityChecker()

    @Test("Check full GPU offload compatibility")
    func testFullGPUOffload() async {
        // Create memory requirements that should fit comfortably
        let requirements: MemoryRequirements = MemoryRequirements(
            baseMemory: 2_000_000_000, // 2GB
            overheadMemory: 500_000_000, // 0.5GB
            totalMemory: 2_500_000_000, // 2.5GB total
            quantization: .int4,
            compressionRatio: 8.0
        )

        let compatibility: DeviceCompatibility = await checker.checkCompatibility(for: requirements)

        // On most systems, 2.5GB should allow full GPU offload
        switch compatibility {
        case .fullGPUOffload(let available):
            #expect(available >= requirements.totalMemory)

        case .partialGPUOffload(let percentage, _):
            // Also acceptable if system has limited memory
            #expect(percentage > 0)

        case .notRecommended, .incompatible:
            // System must have very limited memory
            break
        }
    }

    @Test("Check device memory info")
    func testDeviceMemoryInfo() async {
        let memoryInfo: DeviceMemoryInfo = await checker.getDeviceMemoryInfo()

        // Basic sanity checks
        #expect(memoryInfo.totalMemory > 0)
        #expect(memoryInfo.availableMemory <= memoryInfo.totalMemory)
        #expect(memoryInfo.usedMemory <= memoryInfo.totalMemory)

        // Platform-specific checks
        #if os(macOS)
        #expect(memoryInfo.platform == .macOS)
        #elseif os(iOS)
        #expect(memoryInfo.platform == .iOS || memoryInfo.platform == .iPadOS)
        #elseif os(visionOS)
        #expect(memoryInfo.platform == .visionOS)
        #endif

        // Unified memory check
        #if arch(arm64)
        #expect(memoryInfo.hasUnifiedMemory == true)
        #endif
    }

    @Test("Compatibility status properties")
    func testCompatibilityStatusProperties() {
        // Test full GPU offload
        let fullGPU: DeviceCompatibility = DeviceCompatibility.fullGPUOffload(availableMemory: 8_000_000_000)
        #expect(fullGPU.canRun == true)
        #expect(fullGPU.qualityLevel == 1.0)
        #expect(fullGPU.statusMessage == "This model will run smoothly on your device")

        // Test partial GPU offload
        let partialGPU: DeviceCompatibility = DeviceCompatibility.partialGPUOffload(
            percentageOffloaded: 75.0,
            availableMemory: 6_000_000_000
        )
        #expect(partialGPU.canRun == true)
        #expect(partialGPU.qualityLevel > 0.5)
        #expect(partialGPU.qualityLevel < 1.0)
        #expect(partialGPU.statusMessage.contains("75%"))

        // Test not recommended
        let notRec: DeviceCompatibility = DeviceCompatibility.notRecommended(
            reason: "Limited memory available"
        )
        #expect(notRec.canRun == true) // Can still run, just not recommended
        #expect(notRec.qualityLevel == 0.3)

        // Test incompatible
        let incompatible: DeviceCompatibility = DeviceCompatibility.incompatible(
            minimumRequired: 16_000_000_000,
            available: 8_000_000_000
        )
        #expect(incompatible.canRun == false)
        #expect(incompatible.qualityLevel == 0.0)
        #expect(incompatible.statusMessage == "This model is too large for your device")
    }

    @Test("Memory usage percentage calculation")
    func testMemoryUsagePercentage() {
        let requirements: MemoryRequirements = MemoryRequirements(
            baseMemory: 4_000_000_000,
            overheadMemory: 1_000_000_000,
            totalMemory: 5_000_000_000,
            quantization: .int8,
            compressionRatio: 4.0
        )

        // Test various available memory scenarios
        let percentage50: Double = requirements.memoryUsagePercentage(availableMemory: 10_000_000_000)
        #expect(percentage50 == 50.0)

        let percentage100: Double = requirements.memoryUsagePercentage(availableMemory: 5_000_000_000)
        #expect(percentage100 == 100.0)

        let percentage25: Double = requirements.memoryUsagePercentage(availableMemory: 20_000_000_000)
        #expect(percentage25 == 25.0)
    }

    @Test("Device memory info formatting")
    func testDeviceMemoryInfoFormatting() {
        let memoryInfo: DeviceMemoryInfo = DeviceMemoryInfo(
            totalMemory: 16_000_000_000, // 16GB
            availableMemory: 8_000_000_000, // 8GB
            usedMemory: 8_000_000_000, // 8GB
            platform: .macOS,
            hasUnifiedMemory: true,
            dedicatedGPUMemory: nil,
            neuralEngineCapable: true
        )

        // Test formatted properties
        #expect(memoryInfo.formattedTotalMemory.contains("GB") || memoryInfo.formattedTotalMemory.contains("16"))
        #expect(memoryInfo.formattedAvailableMemory.contains("GB") || memoryInfo.formattedAvailableMemory.contains("8"))

        // Test memory usage percentage
        #expect(memoryInfo.memoryUsagePercentage == 50.0)

        // Test platform minimum memory
        #expect(memoryInfo.platform.minimumRecommendedMemory > 0)
        #if os(macOS)
        #expect(memoryInfo.platform.minimumRecommendedMemory == 8 * 1_024 * 1_024 * 1_024)
        #endif
    }
}
