import Abstractions
import Foundation
import OSLog
#if os(macOS)
import Darwin
import IOKit
#elseif os(iOS) || os(visionOS)
import Darwin
#endif

/// Default implementation of DeviceCompatibilityProtocol
///
/// Provides platform-specific device compatibility checking
/// with detailed memory analysis and recommendations.
public actor DeviceCompatibilityChecker: DeviceCompatibilityProtocol {
    private let logger: ModelDownloaderLogger

    /// Memory reserve configuration for each platform
    private struct MemoryReserveConfig {
        let platform: DeviceMemoryInfo.Platform
        let percentageReserve: Double
        let minimumReserveBytes: UInt64

        static let macOS: MemoryReserveConfig = MemoryReserveConfig(
            platform: .macOS,
            percentageReserve: 0.05,  // 5% of total memory
            minimumReserveBytes: 512 * 1_024 * 1_024  // Min 512MB
        )

        static let iOS: MemoryReserveConfig = MemoryReserveConfig(
            platform: .iOS,
            percentageReserve: 0.10,  // 10% of total memory
            minimumReserveBytes: 256 * 1_024 * 1_024  // Min 256MB
        )

        static let iPadOS: MemoryReserveConfig = MemoryReserveConfig(
            platform: .iPadOS,
            percentageReserve: 0.10,  // 10% of total memory
            minimumReserveBytes: 256 * 1_024 * 1_024  // Min 256MB
        )

        static let visionOS: MemoryReserveConfig = MemoryReserveConfig(
            platform: .visionOS,
            percentageReserve: 0.15,  // 15% of total memory
            minimumReserveBytes: 768 * 1_024 * 1_024  // Min 768MB
        )

        static func config(for platform: DeviceMemoryInfo.Platform) -> MemoryReserveConfig {
            switch platform {
            case .macOS:
                return .macOS

            case .iOS:
                return .iOS

            case .iPadOS:
                return .iPadOS

            case .visionOS:
                return .visionOS
            }
        }
    }

    public init() {
        self.logger = ModelDownloaderLogger(
            subsystem: "com.think.modeldownloader",
            category: "DeviceCompatibility"
        )
    }

    /// Check compatibility for given memory requirements
    public func checkCompatibility(for requirements: MemoryRequirements) async -> DeviceCompatibility {
        let deviceInfo: DeviceMemoryInfo = getDeviceMemoryInfo()

        // Calculate usable memory based on total memory with minimal reserve
        let usableMemory: UInt64 = calculateUsableMemory(deviceInfo)

        await logger.debug(
            """
            Device memory info: total=\(deviceInfo.formattedTotalMemory), \
            available=\(deviceInfo.formattedAvailableMemory), \
            usable=\(ByteCountFormatter.string(fromByteCount: Int64(usableMemory), countStyle: .memory))
            """
        )
        await logger.debug("Requirements: total=\(requirements.formattedTotalMemory)")

        // Full GPU offload check - can we fit the entire model comfortably?
        if requirements.totalMemory <= usableMemory {
            return .fullGPUOffload(availableMemory: usableMemory)
        }

        // Partial GPU offload check - can we at least fit the base model?
        if requirements.baseMemory <= usableMemory {
            let percentageOffloaded: Double = (Double(usableMemory) / Double(requirements.totalMemory)) * 100
            return .partialGPUOffload(
                percentageOffloaded: percentageOffloaded,
                availableMemory: usableMemory
            )
        }

        // Check if model fits in total memory with aggressive swapping
        if requirements.totalMemory <= deviceInfo.totalMemory {
            let memoryRatio: Double = Double(requirements.totalMemory) / Double(deviceInfo.totalMemory)
            if memoryRatio <= 0.85 {
                return .notRecommended(
                    reason: "Model will use \(Int(memoryRatio * 100))% of total memory. Expect slower performance."
                )
            }
            if memoryRatio <= 0.95 {
                return .notRecommended(
                    reason: "Model will use \(Int(memoryRatio * 100))% of total memory. System may become unresponsive."
                )
            }
        }

        // Truly incompatible - model is larger than total system memory
        return .incompatible(
            minimumRequired: requirements.totalMemory,
            available: deviceInfo.totalMemory
        )
    }

    /// Get current device memory information
    public func getDeviceMemoryInfo() -> DeviceMemoryInfo {
        let platform: DeviceMemoryInfo.Platform = detectPlatform()
        let memoryInfo: SystemMemoryInfo = getSystemMemoryInfo()

        return DeviceMemoryInfo(
            totalMemory: memoryInfo.total,
            availableMemory: memoryInfo.available,
            usedMemory: memoryInfo.used,
            platform: platform,
            hasUnifiedMemory: hasUnifiedMemoryArchitecture(),
            dedicatedGPUMemory: getDedicatedGPUMemory(),
            neuralEngineCapable: hasNeuralEngine()
        )
    }

    // MARK: - Platform Detection

    private
    func detectPlatform() -> DeviceMemoryInfo.Platform {
        #if os(macOS)
        return .macOS
        #elseif os(iOS)
        // Check device model using sysctlbyname to avoid MainActor issues
        var systemInfo: utsname = utsname()
        uname(&systemInfo)
        let machine: String? = withUnsafePointer(to: &systemInfo.machine) { pointer in
            pointer.withMemoryRebound(to: CChar.self, capacity: 1) { cCharPointer in
                String(validatingCString: cCharPointer)
            }
        }

        // iPad models contain "iPad" in their machine identifier
        if let machineString = machine, machineString.contains("iPad") {
            return .iPadOS
        }
        return .iOS
        #elseif os(visionOS)
        return .visionOS
        #else
        return .iOS // Default fallback
        #endif
    }

    func hasUnifiedMemoryArchitecture() -> Bool {
        #if os(macOS)
        // Use sysctlbyname for robust Apple Silicon detection
        var isAppleSilicon: Int32 = 0
        var size: size_t = MemoryLayout<Int32>.size
        let result: Int32 = sysctlbyname("hw.optional.arm64", &isAppleSilicon, &size, nil, 0)

        if result == 0 {
            let hasUnified: Bool = isAppleSilicon == 1
            // Log asynchronously without blocking
            Task { [logger] in
                await logger.debug("Apple Silicon detection via sysctlbyname: \(hasUnified)")
            }
            return hasUnified
        }

        // Fallback: Check if running on iOS app on Mac
        if ProcessInfo.processInfo.isiOSAppOnMac {
            return true
        }

        // Final fallback: Check machine type
        var systemInfo: utsname = utsname()
        uname(&systemInfo)
        let machine: String? = withUnsafePointer(to: &systemInfo.machine) { pointer in
            pointer.withMemoryRebound(to: CChar.self, capacity: 1) { cCharPointer in
                String(validatingCString: cCharPointer)
            }
        }
        return machine?.contains("arm64") ?? false
        #else
        // All iOS devices have unified memory
        return true
        #endif
    }

    func hasNeuralEngine() -> Bool {
        // All recent Apple Silicon devices have Neural Engine
        #if os(macOS)
        return hasUnifiedMemoryArchitecture()
        #else
        return true
        #endif
    }

    // MARK: - Memory Information

    private
    struct SystemMemoryInfo {
        let total: UInt64
        let available: UInt64
        let used: UInt64
    }

    private func getSystemMemoryInfo() -> SystemMemoryInfo {
        let totalMemory: UInt64 = ProcessInfo.processInfo.physicalMemory

        #if targetEnvironment(simulator)
        return getSimulatorMemoryInfo(totalMemory: totalMemory)
        #elseif os(macOS)
        return getMacOSMemoryInfo(totalMemory: totalMemory)
        #elseif os(iOS) && !targetEnvironment(macCatalyst)
        return getIOSMemoryInfo(totalMemory: totalMemory)
        #elseif os(visionOS)
        return getVisionOSMemoryInfo(totalMemory: totalMemory)
        #else
        return getFallbackMemoryInfo(totalMemory: totalMemory)
        #endif
    }

    // MARK: - Platform-Specific Memory Calculation

    private func getSimulatorMemoryInfo(totalMemory: UInt64) -> SystemMemoryInfo {
        // Simulator doesn't have proper memory reporting, use reasonable defaults
        let estimatedUsed: UInt64 = totalMemory / 20  // Assume 5% used
        let availableMemory: UInt64 = totalMemory - estimatedUsed

        Task { [logger] in
            await logger.debug(
                """
                Simulator memory (estimated): \
                total=\(totalMemory), \
                used=\(estimatedUsed), \
                available=\(availableMemory)
                """
            )
        }

        return SystemMemoryInfo(
            total: totalMemory,
            available: availableMemory,
            used: estimatedUsed
        )
    }

    #if os(macOS)
    private func getMacOSMemoryInfo(totalMemory: UInt64) -> SystemMemoryInfo {
        var info: vm_statistics64 = vm_statistics64()
        var count: mach_msg_type_number_t = mach_msg_type_number_t(MemoryLayout<vm_statistics64>.size) / 4

        // Validate buffer size
        let expectedCount: Int = MemoryLayout<vm_statistics64>.size / MemoryLayout<integer_t>.size
        guard count == expectedCount else {
            return getFallbackMemoryInfo(totalMemory: totalMemory)
        }

        let host: host_t = mach_host_self()
        defer {
            mach_port_deallocate(mach_task_self_, host)
        }

        let result: kern_return_t = withUnsafeMutablePointer(to: &info) { pointer in
            pointer.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { integerPointer in
                host_statistics64(host, HOST_VM_INFO64, integerPointer, &count)
            }
        }

        guard result == KERN_SUCCESS else {
            return getFallbackMemoryInfo(totalMemory: totalMemory)
        }

        var pageSize: vm_size_t = 0
        var pageSizeSize: size_t = MemoryLayout<vm_size_t>.size
        _ = sysctlbyname("hw.pagesize", &pageSize, &pageSizeSize, nil, 0)
        let pageSizeUInt64: UInt64 = UInt64(pageSize)
        let freeMemory: UInt64 = UInt64(info.free_count) * pageSizeUInt64
        let inactiveMemory: UInt64 = UInt64(info.inactive_count) * pageSizeUInt64
        let availableMemory: UInt64 = freeMemory + inactiveMemory
        let usedMemory: UInt64 = totalMemory > availableMemory ? totalMemory - availableMemory : 0

        Task { [logger] in
            await logger.debug(
                """
                macOS memory: \
                free=\(ByteCountFormatter.string(fromByteCount: Int64(freeMemory), countStyle: .memory)), \
                inactive=\(ByteCountFormatter.string(fromByteCount: Int64(inactiveMemory), countStyle: .memory)), \
                available=\(ByteCountFormatter.string(fromByteCount: Int64(availableMemory), countStyle: .memory))
                """
            )
        }

        return SystemMemoryInfo(
            total: totalMemory,
            available: availableMemory,
            used: usedMemory
        )
    }
    #endif

    #if os(iOS) && !targetEnvironment(macCatalyst)
    private func getIOSMemoryInfo(totalMemory: UInt64) -> SystemMemoryInfo {
        if #available(iOS 13.0, *) {
            let availableMemory: Int = os_proc_available_memory()
            let usedMemory: UInt64 = availableMemory < totalMemory ? totalMemory - UInt64(availableMemory) : 0

            Task { [logger] in
                await logger.debug(
                    "iOS memory via os_proc_available_memory: total=\(totalMemory), available=\(availableMemory)"
                )
            }

            return SystemMemoryInfo(
                total: totalMemory,
                available: UInt64(availableMemory),
                used: usedMemory
            )
        } else {
            return getIOSFallbackMemoryInfo(totalMemory: totalMemory)
        }
    }

    private func getIOSFallbackMemoryInfo(totalMemory: UInt64) -> SystemMemoryInfo {
        var info: mach_task_basic_info = mach_task_basic_info()
        var count: mach_msg_type_number_t = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size) / 4

        // Validate buffer size
        let expectedCount: Int = MemoryLayout<mach_task_basic_info>.size / MemoryLayout<integer_t>.size
        guard count == expectedCount else {
            return getFallbackMemoryInfo(totalMemory: totalMemory)
        }

        let result: kern_return_t = withUnsafeMutablePointer(to: &info) { pointer in
            pointer.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { integerPointer in
                task_info(
                    mach_task_self_,
                    task_flavor_t(MACH_TASK_BASIC_INFO),
                    integerPointer,
                    &count
                )
            }
        }

        guard result == KERN_SUCCESS else {
            return getFallbackMemoryInfo(totalMemory: totalMemory)
        }

        let usedMemory: UInt64 = info.resident_size
        let availableMemory: UInt64 = totalMemory > usedMemory ? totalMemory - usedMemory : totalMemory / 2

        Task { [logger] in
            await logger.debug(
                """
                iOS memory: \
                total=\(totalMemory), \
                used=\(usedMemory), \
                available=\(availableMemory)
                """
            )
        }

        return SystemMemoryInfo(
            total: totalMemory,
            available: availableMemory,
            used: usedMemory
        )
    }
    #endif

    #if os(visionOS)
    private func getVisionOSMemoryInfo(totalMemory: UInt64) -> SystemMemoryInfo {
        // VisionOS has limited memory reporting capabilities
        // Use conservative estimates
        let estimatedUsed: UInt64 = totalMemory * 2 / 5  // Assume 40% used
        let availableMemory: UInt64 = totalMemory - estimatedUsed

        Task { [logger] in
            await logger.debug(
                """
                visionOS memory (estimated): \
                total=\(totalMemory), \
                used=\(estimatedUsed), \
                available=\(availableMemory)
                """
            )
        }

        return SystemMemoryInfo(
            total: totalMemory,
            available: availableMemory,
            used: estimatedUsed
        )
    }
    #endif

    private func getFallbackMemoryInfo(totalMemory: UInt64) -> SystemMemoryInfo {
        // Conservative fallback calculation
        let estimatedUsed: UInt64 = totalMemory / 2
        let availableMemory: UInt64 = totalMemory - estimatedUsed

        Task { [logger] in
            await logger.debug(
                """
                Fallback memory (estimated): \
                total=\(totalMemory), \
                used=\(estimatedUsed), \
                available=\(availableMemory)
                """
            )
        }

        return SystemMemoryInfo(
            total: totalMemory,
            available: availableMemory,
            used: estimatedUsed
        )
    }

    func getDedicatedGPUMemory() -> UInt64? {
        #if os(macOS)
        // Check for discrete GPU memory
        // This would require IOKit queries for discrete GPUs
        // For now, return nil for unified memory systems
        if hasUnifiedMemoryArchitecture() {
            return nil
        }
        // Would need IOKit implementation for Intel Macs with discrete GPUs
        #endif
        return nil
    }

    func calculateUsableMemory(_ info: DeviceMemoryInfo) -> UInt64 {
        // Get platform-specific memory reserve configuration
        let config: MemoryReserveConfig = MemoryReserveConfig.config(for: info.platform)

        // Calculate reserve based on percentage of total memory
        let percentageBasedReserve: UInt64 = UInt64(Double(info.totalMemory) * config.percentageReserve)

        // Use the larger of percentage-based or minimum reserve
        let actualReserve: UInt64 = max(percentageBasedReserve, config.minimumReserveBytes)

        // Calculate usable memory (total minus reserve)
        let usableMemory: UInt64 = info.totalMemory > actualReserve
            ? info.totalMemory - actualReserve
            : info.totalMemory / 2

        Task { [logger] in
            await logger.debug(
                """
                Usable memory calculation: \
                total=\(ByteCountFormatter.string(fromByteCount: Int64(info.totalMemory), countStyle: .memory)), \
                reserve=\(ByteCountFormatter.string(fromByteCount: Int64(actualReserve), countStyle: .memory)) \
                (\(Int(config.percentageReserve * 100))% or min \
                \(ByteCountFormatter.string(fromByteCount: Int64(config.minimumReserveBytes), countStyle: .memory))), \
                usable=\(ByteCountFormatter.string(fromByteCount: Int64(usableMemory), countStyle: .memory))
                """
            )
        }

        return usableMemory
    }
}
