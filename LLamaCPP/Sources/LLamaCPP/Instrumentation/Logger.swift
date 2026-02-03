import Abstractions
import Foundation
import llama
import os

/// Structured logger for LlamaCPP operations
/// Focuses on important events and errors only, no per-token logging
internal enum Logger {
    /// Main logger for LlamaCPP subsystem
    private static let log: os.Logger = os.Logger(
        subsystem: "LLamaCPP",
        category: "LlamaCPP"
    )

    // MARK: - Model Lifecycle

    /// Log model loading start
    internal static func modelLoadStarted(path: String) {
        log.info("Starting model load from: \(path, privacy: .public)")
    }

    /// Log successful model load with timing
    internal static func modelLoadCompleted(duration: TimeInterval, modelSize: Int64? = nil) {
        if let size = modelSize {
            let bytesPerMB: Double = 1_048_576
            let sizeMB: Double = Double(size) / bytesPerMB
            let precision2: Int = 2
            log.info("Model: \(duration, format: .fixed(precision: precision2))s, \(sizeMB)MB")
        } else {
            let precision2: Int = 2
            log.info("Model loaded successfully in \(duration, format: .fixed(precision: precision2))s")
        }
    }

    /// Log model load failure
    internal static func modelLoadFailed(error: Error) {
        log.error("Model load failed: \(error.localizedDescription, privacy: .public)")
    }

    /// Log model unload
    internal static func modelUnloaded() {
        log.info("Model unloaded from memory")
    }

    // MARK: - Context Operations

    /// Log context creation with parameters
    internal static func contextCreated(contextSize: Int32, batchSize: Int32) {
        log.info("Context created with size: \(contextSize), batch: \(batchSize)")
    }

    /// Log context creation failure
    internal static func contextCreationFailed(error: Error) {
        log.error("Context creation failed: \(error.localizedDescription, privacy: .public)")
    }

    // MARK: - Generation Events

    /// Log generation start with key parameters
    internal static func generationStarted(promptTokens: Int, maxTokens: Int) {
        log.info("Generation started - prompt tokens: \(promptTokens), max tokens: \(maxTokens)")
    }

    /// Log generation completion with metrics
    internal static func generationCompleted(
        generatedTokens: Int,
        tokensPerSecond: Double?,
        stopReason: String
    ) {
        if let tps = tokensPerSecond {
            log.info("Gen done: \(generatedTokens) tok, \(tps, format: .fixed(precision: 1)) TPS")
        } else {
            log.info(
                "Generation done - tokens: \(generatedTokens), stop: \(stopReason, privacy: .public)"
            )
        }
    }

    /// Log generation cancellation
    internal static func generationCancelled(reason: String) {
        log.warning("Generation cancelled: \(reason, privacy: .public)")
    }

    /// Log generation error
    internal static func generationFailed(error: Error) {
        log.error("Generation failed: \(error.localizedDescription, privacy: .public)")
    }

    /// Log stop sequence detection
    internal static func stopSequenceDetected(sequence: String) {
        log.info("Stop sequence detected: '\(sequence, privacy: .public)'")
    }

    // MARK: - Resource Warnings

    /// Log when approaching context window limit
    internal static func contextWindowWarning(used: Int, total: Int) {
        let percentConversion: Double = 100
        let percentage: Double = (Double(used) / Double(total)) * percentConversion
        log.warning(
            "Context window usage high: \(used)/\(total) (\(percentage, format: .fixed(precision: 0))%)"
        )
    }

    /// Log when prompt tokens are truncated to fit the context window
    internal static func promptTruncated(
        original: Int,
        trimmed: Int,
        contextSize: Int,
        requestedMaxTokens: Int
    ) {
        let message: String = "Prompt truncated: \(original)->\(trimmed) tokens " +
            "to fit context \(contextSize) with maxTokens \(requestedMaxTokens)"
        log.warning("\(message)")
    }

    /// Log when max tokens are clamped to fit the context window
    internal static func maxTokensClamped(
        requested: Int,
        effective: Int,
        contextSize: Int
    ) {
        log.warning(
            "Max tokens clamped: \(requested)->\(effective) to fit context \(contextSize)"
        )
    }

    /// Log memory pressure warning
    internal static func memoryPressureWarning() {
        log.warning("Memory pressure detected during generation")
    }

    // MARK: - Performance Milestones

    /// Log time to first token (important UX metric)
    internal static func timeToFirstToken(duration: TimeInterval) {
        let msPerSecond: Double = 1_000
        log.info("Time to first token: \(duration * msPerSecond, format: .fixed(precision: 0))ms")
    }

    /// Log prompt processing completion
    internal static func promptProcessingCompleted(duration: TimeInterval, tokenCount: Int) {
        let tokensPerSecond: Double = Double(tokenCount) / duration
        let precision3: Int = 3
        log.debug("Prompt: \(duration, format: .fixed(precision: precision3))s, \(Int(tokensPerSecond)) t/s")
    }

    // MARK: - Error Conditions

    /// Log invalid configuration
    internal static func invalidConfiguration(message: String) {
        log.error("Invalid configuration: \(message, privacy: .public)")
    }

    /// Log resource exhaustion
    internal static func resourceExhausted(resource: String) {
        log.error("Resource exhausted: \(resource, privacy: .public)")
    }

    /// Log unexpected state
    internal static func unexpectedState(message: String) {
        log.fault("Unexpected state: \(message, privacy: .public)")
    }

    // MARK: - Parameter Logging

    /// Log platform information and capabilities
    internal static func logPlatformInfo() {
        let platform: String = getPlatformName()
        let cores: Int = ProcessInfo.processInfo.processorCount
        let memory: UInt64 = ProcessInfo.processInfo.physicalMemory
        let kilobytes: Double = 1_024
        let bytesPerGB: Double = kilobytes * kilobytes * kilobytes
        let memoryGB: Double = Double(memory) / bytesPerGB

        log.info("""
            Platform: \(platform, privacy: .public)
            Cores: \(cores), Memory: \(String(format: "%.1f", memoryGB))GB
            """)
    }

    private static func getPlatformName() -> String {
        #if os(macOS)
        return "macOS"
        #elseif os(iOS)
        return "iOS"
        #elseif os(visionOS)
        return "visionOS"
        #elseif targetEnvironment(simulator)
        return "Simulator"
        #else
        return "Unknown"
        #endif
    }

    /// Log model parameters used for loading
    internal static func logModelParameters(_ params: llama_model_params) {
        log.info("""
            Model Parameters:
            - GPU Layers: \(params.n_gpu_layers)
            - Main GPU: \(params.main_gpu)
            - Split Mode: \(params.split_mode.rawValue)
            - Use mmap: \(params.use_mmap)
            - Use mlock: \(params.use_mlock)
            - Check tensors: \(params.check_tensors)
            - Vocab only: \(params.vocab_only)
            """)
    }

    /// Log context parameters used for creation
    internal static func logContextParameters(_ params: llama_context_params) {
        let kvTypeK: String = ggmlTypeToString(params.type_k)
        let kvTypeV: String = ggmlTypeToString(params.type_v)
        let ropeType: String = ropeScalingTypeToString(Int32(params.rope_scaling_type.rawValue))

        log.info("""
            Context Parameters:
            - Context Size: \(params.n_ctx)
            - Batch Size: \(params.n_batch)
            - Ubatch Size: \(params.n_ubatch)
            - Threads: \(params.n_threads)
            - Threads Batch: \(params.n_threads_batch)
            - KV Type K: \(kvTypeK, privacy: .public)
            - KV Type V: \(kvTypeV, privacy: .public)
            - Flash Attention: \(params.flash_attn)
            - Offload KQV: \(params.offload_kqv)
            - RoPE Scaling: \(ropeType, privacy: .public)
            - RoPE Base: \(params.rope_freq_base)
            - RoPE Scale: \(params.rope_freq_scale)
            """)
    }

    /// Log sampling configuration
    internal static func logSamplingConfiguration(_ sampling: SamplingParameters) {
        let stopSeqInfo: String = sampling.stopSequences.isEmpty
            ? "none"
            : "\(sampling.stopSequences.count) [\(sampling.stopSequences.joined(separator: ", "))]"

        log.info("""
            Sampling Configuration:
            - Temperature: \(sampling.temperature)
            - Top-P: \(sampling.topP)
            - Top-K: \(sampling.topK ?? -1)
            - Repetition Penalty: \(sampling.repetitionPenalty ?? 1.0)
            - Frequency Penalty: \(sampling.frequencyPenalty ?? 0.0)
            - Presence Penalty: \(sampling.presencePenalty ?? 0.0)
            - Rep Penalty Range: \(sampling.repetitionPenaltyRange ?? defaultPenaltyRange)
            - Seed: \(sampling.seed ?? -1)
            - Stop Sequences: \(stopSeqInfo, privacy: .public)
            """)
    }

    /// Log actual hardware capabilities detected
    internal static func logHardwareCapabilities(hasMetalSupport: Bool, gpuLayersOffloaded: Int32) {
        log.info("""
            Hardware Capabilities:
            - Metal Support: \(hasMetalSupport)
            - GPU Layers Offloaded: \(gpuLayersOffloaded)
            """)
    }

    // MARK: - Private Helpers

    private static let defaultPenaltyRange: Int = 64

    private static func ggmlTypeToString(_ type: ggml_type) -> String {
        let typeMap: [ggml_type: String] = [
            GGML_TYPE_F32: "F32",
            GGML_TYPE_F16: "F16",
            GGML_TYPE_Q4_0: "Q4_0",
            GGML_TYPE_Q4_1: "Q4_1",
            GGML_TYPE_Q5_0: "Q5_0",
            GGML_TYPE_Q5_1: "Q5_1",
            GGML_TYPE_Q8_0: "Q8_0",
            GGML_TYPE_Q8_1: "Q8_1"
        ]
        return typeMap[type] ?? "Unknown"
    }

    private static func ropeScalingTypeToString(_ type: Int32) -> String {
        switch type {
        case Int32(LLAMA_ROPE_SCALING_TYPE_NONE.rawValue):
            return "None"

        case Int32(LLAMA_ROPE_SCALING_TYPE_LINEAR.rawValue):
            return "Linear"

        case Int32(LLAMA_ROPE_SCALING_TYPE_YARN.rawValue):
            return "YaRN"

        default:
            return "Unknown"
        }
    }
}
