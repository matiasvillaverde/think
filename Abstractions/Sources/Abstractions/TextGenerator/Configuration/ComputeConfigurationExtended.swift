import Foundation

/// Extended configuration for compute resources with GPU and advanced parameters
public struct ComputeConfigurationExtended: Sendable, Equatable {
    // MARK: - Core Parameters (from original ComputeConfiguration)

    /// The maximum context size in tokens
    public let contextSize: Int

    /// The batch size for processing tokens
    public let batchSize: Int

    /// The number of threads to use for computation
    public let threadCount: Int

    // MARK: - GPU Parameters

    /// Number of layers to offload to GPU (-1 for all, 0 for none, or specific count)
    public let gpuLayers: Int

    /// Whether to offload KV cache to GPU
    public let offloadKQV: Bool

    /// How to split model across multiple GPUs
    public let splitMode: SplitMode

    /// Main GPU index to use (0-based)
    public let mainGPU: Int

    /// Whether to offload operations to GPU
    public let opOffload: Bool

    // MARK: - Performance Parameters

    /// Micro-batch size for decoding (nil to use batch size)
    public let microBatchSize: Int?

    /// Enable Flash Attention if supported
    public let flashAttention: Bool

    /// KV cache quantization type
    public let kvCacheType: KVCacheType

    /// Lock model in RAM (macOS only)
    public let useMlock: Bool

    // MARK: - RoPE Configuration

    /// RoPE scaling type for extended context
    public let ropeScaling: RopeScalingType

    /// RoPE frequency base (nil for model default)
    public let ropeFreqBase: Float?

    /// RoPE frequency scale (nil for model default)
    public let ropeFreqScale: Float?

    // MARK: - Initialization

    /// Initialize with all parameters
    public init(
        contextSize: Int,
        batchSize: Int,
        threadCount: Int,
        gpuLayers: Int = -1,
        offloadKQV: Bool = true,
        splitMode: SplitMode = .layer,
        mainGPU: Int = 0,
        opOffload: Bool = true,
        microBatchSize: Int? = nil,
        flashAttention: Bool = false,
        kvCacheType: KVCacheType = .f16,
        useMlock: Bool = false,
        ropeScaling: RopeScalingType = .noScaling,
        ropeFreqBase: Float? = nil,
        ropeFreqScale: Float? = nil
    ) {
        self.contextSize = contextSize
        self.batchSize = batchSize
        self.threadCount = threadCount
        self.gpuLayers = gpuLayers
        self.offloadKQV = offloadKQV
        self.splitMode = splitMode
        self.mainGPU = mainGPU
        self.opOffload = opOffload
        self.microBatchSize = microBatchSize
        self.flashAttention = flashAttention
        self.kvCacheType = kvCacheType
        self.useMlock = useMlock
        self.ropeScaling = ropeScaling
        self.ropeFreqBase = ropeFreqBase
        self.ropeFreqScale = ropeFreqScale
    }

    /// Create from basic ComputeConfiguration with GPU defaults
    public init(from basic: ComputeConfiguration, gpuEnabled: Bool = true) {
        self.init(
            contextSize: basic.contextSize,
            batchSize: basic.batchSize,
            threadCount: basic.threadCount,
            gpuLayers: gpuEnabled ? -1 : 0,
            offloadKQV: gpuEnabled,
            opOffload: gpuEnabled
        )
    }
}

// MARK: - Platform-Specific Presets

extension ComputeConfigurationExtended {
    /// Optimized configuration for macOS with Metal support
    public static func macOSOptimized(contextSize: Int = 4096) -> ComputeConfigurationExtended {
        ComputeConfigurationExtended(
            contextSize: contextSize,
            batchSize: 512,
            threadCount: min(8, ProcessInfo.processInfo.processorCount),
            gpuLayers: -1,  // Use all layers on GPU
            offloadKQV: true,
            splitMode: .layer,
            mainGPU: 0,
            opOffload: true,
            microBatchSize: 512,
            flashAttention: false,  // Not always supported
            kvCacheType: .f16,
            useMlock: true,  // Lock in RAM on macOS
            ropeScaling: .noScaling
        )
    }

    /// Optimized configuration for iOS/iPad devices
    public static func iOSOptimized(contextSize: Int = 2048) -> ComputeConfigurationExtended {
        ComputeConfigurationExtended(
            contextSize: contextSize,
            batchSize: 256,
            threadCount: min(4, ProcessInfo.processInfo.processorCount),
            gpuLayers: 20,  // Partial GPU offload
            offloadKQV: false,  // Save GPU memory
            splitMode: .noSplit,
            mainGPU: 0,
            opOffload: true,
            microBatchSize: 128,
            flashAttention: false,
            kvCacheType: .q8_0,  // Compressed for mobile
            useMlock: false,
            ropeScaling: .noScaling
        )
    }

    /// Optimized configuration for visionOS
    public static func visionOSOptimized(contextSize: Int = 2048) -> ComputeConfigurationExtended {
        ComputeConfigurationExtended(
            contextSize: contextSize,
            batchSize: 256,
            threadCount: min(4, ProcessInfo.processInfo.processorCount),
            gpuLayers: 16,  // Conservative GPU usage
            offloadKQV: false,
            splitMode: .noSplit,
            mainGPU: 0,
            opOffload: true,
            microBatchSize: 128,
            flashAttention: false,
            kvCacheType: .q8_0,
            useMlock: false,
            ropeScaling: .noScaling
        )
    }

    /// CPU-only configuration (for testing or fallback)
    public static func cpuOnly(contextSize: Int = 2048) -> ComputeConfigurationExtended {
        ComputeConfigurationExtended(
            contextSize: contextSize,
            batchSize: 256,
            threadCount: ProcessInfo.processInfo.processorCount,
            gpuLayers: 0,  // No GPU
            offloadKQV: false,
            splitMode: .noSplit,
            mainGPU: 0,
            opOffload: false,
            microBatchSize: nil,
            flashAttention: false,
            kvCacheType: .f16,
            useMlock: false,
            ropeScaling: .noScaling
        )
    }

    /// Auto-detect best configuration for current platform
    public static func optimizedForCurrentDevice(contextSize: Int = 4096) -> ComputeConfigurationExtended {
        #if os(macOS)
        return macOSOptimized(contextSize: contextSize)
        #elseif os(iOS)
        return iOSOptimized(contextSize: contextSize)
        #elseif os(visionOS)
        return visionOSOptimized(contextSize: contextSize)
        #else
        return cpuOnly(contextSize: contextSize)
        #endif
    }

    /// Performance-focused configuration (maximum speed)
    public static func performance(contextSize: Int = 4096) -> ComputeConfigurationExtended {
        ComputeConfigurationExtended(
            contextSize: contextSize,
            batchSize: 1024,
            threadCount: ProcessInfo.processInfo.processorCount,
            gpuLayers: -1,
            offloadKQV: true,
            splitMode: .layer,
            mainGPU: 0,
            opOffload: true,
            microBatchSize: 1024,
            flashAttention: true,
            kvCacheType: .q8_0,  // Faster with some quality trade-off
            useMlock: true,
            ropeScaling: .noScaling
        )
    }

    /// Quality-focused configuration (best output quality)
    public static func quality(contextSize: Int = 4096) -> ComputeConfigurationExtended {
        ComputeConfigurationExtended(
            contextSize: contextSize,
            batchSize: 512,
            threadCount: min(8, ProcessInfo.processInfo.processorCount),
            gpuLayers: -1,
            offloadKQV: true,
            splitMode: .layer,
            mainGPU: 0,
            opOffload: true,
            microBatchSize: 512,
            flashAttention: false,
            kvCacheType: .f32,  // Maximum precision
            useMlock: true,
            ropeScaling: .noScaling
        )
    }

    /// Balanced configuration (good trade-off)
    public static func balanced(contextSize: Int = 4096) -> ComputeConfigurationExtended {
        ComputeConfigurationExtended(
            contextSize: contextSize,
            batchSize: 512,
            threadCount: min(8, ProcessInfo.processInfo.processorCount),
            gpuLayers: -1,
            offloadKQV: true,
            splitMode: .layer,
            mainGPU: 0,
            opOffload: true,
            microBatchSize: 512,
            flashAttention: false,
            kvCacheType: .f16,  // Good balance
            useMlock: false,
            ropeScaling: .noScaling
        )
    }

    /// Low power configuration for background tasks
    public static func lowPower(contextSize: Int = 1024) -> ComputeConfigurationExtended {
        ComputeConfigurationExtended(
            contextSize: contextSize,
            batchSize: 128,
            threadCount: 2,
            gpuLayers: 8,  // Minimal GPU usage
            offloadKQV: false,
            splitMode: .noSplit,
            mainGPU: 0,
            opOffload: false,
            microBatchSize: 64,
            flashAttention: false,
            kvCacheType: .q4_0,  // Maximum compression
            useMlock: false,
            ropeScaling: .noScaling
        )
    }
}

// MARK: - Conversion to Basic ComputeConfiguration

extension ComputeConfigurationExtended {
    /// Convert to basic ComputeConfiguration (for backward compatibility)
    public func toBasic() -> ComputeConfiguration {
        ComputeConfiguration(
            contextSize: contextSize,
            batchSize: batchSize,
            threadCount: threadCount
        )
    }
}
