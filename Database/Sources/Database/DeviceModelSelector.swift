import Foundation
import Abstractions
import OSLog

/// Selects optimal default models based on device capabilities
public struct DeviceModelSelector {
    /// Logger for device selection operations
    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "",
        category: "DeviceModelSelector"
    )

    /// Configuration for a model
    private struct ModelConfig {
        let name: String
        let huggingfaceId: String
        let ramNeeded: UInt64
        let size: UInt64
        let backend: SendableModel.Backend
    }

    /// Device memory thresholds for model selection
    private enum MemoryThreshold {
        static let lowMemory: UInt64 = 8.gigabytes
        static let mediumMemory: UInt64 = 16.gigabytes
        static let highMemory: UInt64 = 32.gigabytes
    }

    /// Device capabilities assessment
    public struct DeviceCapabilities {
        public let totalMemory: UInt64
        public let availableMemory: UInt64
        let supportedBackends: [SendableModel.Backend]
        let architecture: String
        public let platform: String

        init() {
            self.totalMemory = ProcessInfo.processInfo.physicalMemory
            self.availableMemory = Self.calculateAvailableMemory()
            self.supportedBackends = Self.detectSupportedBackends()
            self.architecture = Self.getArchitecture()
            self.platform = Self.getPlatform()
        }

        private static func calculateAvailableMemory() -> UInt64 {
            // Reserve 2GB for system and other apps
            let totalMemory = ProcessInfo.processInfo.physicalMemory
            let reservedMemory: UInt64 = 2.gigabytes
            return totalMemory > reservedMemory ? totalMemory - reservedMemory : totalMemory / 2
        }

        private static func detectSupportedBackends() -> [SendableModel.Backend] {
            var backends: [SendableModel.Backend] = []

            #if os(macOS) || os(iOS) || os(visionOS)
            // Apple Silicon supports MLX and CoreML
            backends.append(.mlx)
            backends.append(.coreml)
            #endif

            // All platforms support GGUF
            backends.append(.gguf)

            return backends
        }

        private static func getArchitecture() -> String {
            #if arch(arm64)
            return "arm64"
            #elseif arch(x86_64)
            return "x86_64"
            #else
            return "unknown"
            #endif
        }

        private static func getPlatform() -> String {
            #if os(macOS)
            return "macOS"
            #elseif os(iOS)
            return "iOS"
            #elseif os(visionOS)
            return "visionOS"
            #else
            return "unknown"
            #endif
        }

        public var memoryCategory: String {
            switch availableMemory {
            case 0..<MemoryThreshold.lowMemory:
                return "low"
            case MemoryThreshold.lowMemory..<MemoryThreshold.mediumMemory:
                return "medium"
            default:
                return "high"
            }
        }
    }

    /// Default image models optimized for different device capabilities using shared recommended models
    public static func getOptimalImageModel(for capabilities: DeviceCapabilities) throws -> Model {
        logger.info("Selecting optimal image model for device with \(capabilities.totalMemory / 1024 / 1024 / 1024)GB memory")

        let modelConfig = ModelConfig(
            name: "Stable Diffusion v1.5",
            huggingfaceId: "coreml-community/coreml-Inkpunk-Diffusion",
            ramNeeded: 3.gigabytes,
            size: 1.97.gigabytes,
            backend: .coreml
        )

        logger.info("Selected image model: \(modelConfig.huggingfaceId) (RAM: \(modelConfig.ramNeeded / 1024 / 1024 / 1024)GB)")

        return try Model(
            type: .diffusion,
            backend: modelConfig.backend,
            name: modelConfig.name,
            displayName: modelConfig.name,
            displayDescription: "Optimized image generation model for \(capabilities.memoryCategory) memory devices",
            author: "mlx-community",
            license: "openrail",
            tags: ["image-generation", "stable-diffusion", "diffusion", "optimized"],
            skills: ["image-generation", "text-to-image"],
            parameters: 860_000_000,
            ramNeeded: modelConfig.ramNeeded,
            size: modelConfig.size,
            locationHuggingface: modelConfig.huggingfaceId,
            version: 2
        )
    }
    /// Get device capabilities for current device
    public static func getCurrentDeviceCapabilities() -> DeviceCapabilities {
        let capabilities = DeviceCapabilities()
        let totalGB = capabilities.totalMemory / 1024 / 1024 / 1024
        let availableGB = capabilities.availableMemory / 1024 / 1024 / 1024
        logger.info("Device capabilities: \(totalGB)GB total, \(availableGB)GB available, \(capabilities.memoryCategory) memory category")
        return capabilities
    }
}

extension UInt64 {
    static var gigabyte: UInt64 { 1024 * 1024 * 1024 }
}
