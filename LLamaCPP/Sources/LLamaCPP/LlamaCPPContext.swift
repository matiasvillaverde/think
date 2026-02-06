import Abstractions
import Foundation
import llama

/// Context wrapper for llama.cpp
/// Note: This class is NOT thread-safe and should only be used within LlamaCPPSession actor
internal final class LlamaCPPContext {
    internal private(set) var pointer: OpaquePointer?
    internal private(set) var resetEpoch: UInt64 = 0

    /// The model this context is associated with
    private let model: LlamaCPPModel

    /// Configuration used to create this context
    internal let configuration: ComputeConfiguration

    /// Default sequence ID
    internal let sequenceId: Int32 = 0

    /// Initialize context with a model
    /// - Parameters:
    ///   - model: The loaded LlamaCPP model
    ///   - configuration: Configuration for context
    /// - Throws: LlamaCPPError if context cannot be created
    internal init(
        model: LlamaCPPModel,
        configuration: ComputeConfiguration
    ) throws {
        guard model.pointer != nil else {
            throw LLMError.invalidConfiguration("Model has been freed")
        }

        self.model = model
        self.configuration = configuration
        self.pointer = nil // Initialize first

        // Create context
        let ctx: OpaquePointer = try createContext(model: model)
        self.pointer = ctx
    }

    internal static func resolveContextSize(configured: Int, slidingWindow: Int) -> Int {
        let safeConfigured: Int = max(1, configured)
        let safeSliding: Int = max(0, slidingWindow)
        return max(safeConfigured, safeSliding)
    }

    internal static func resolveBatchSize(configured: Int, contextSize: Int) -> Int {
        let safeConfigured: Int = max(1, configured)
        let safeContext: Int = max(1, contextSize)
        return min(safeConfigured, safeContext)
    }

    internal static func resolveMicroBatchSize(configured: Int?, batchSize: Int) -> Int {
        let safeBatch: Int = max(1, batchSize)
        guard let configured else {
            return safeBatch
        }
        return max(1, min(configured, safeBatch))
    }

    internal static func buildContextParams(
        configuration: ComputeConfiguration,
        modelConfiguration: ComputeConfigurationExtended,
        slidingWindow: Int
    ) -> llama_context_params {
        LlamaCPPModel.ensureBackendInitialized()
        var params: llama_context_params = llama_context_default_params()

        applySizingParams(
            configuration: configuration,
            modelConfiguration: modelConfiguration,
            slidingWindow: slidingWindow,
            to: &params
        )
        applyExecutionParams(modelConfiguration: modelConfiguration, to: &params)

        return params
    }

    private static func applySizingParams(
        configuration: ComputeConfiguration,
        modelConfiguration: ComputeConfigurationExtended,
        slidingWindow: Int,
        to params: inout llama_context_params
    ) {
        let effectiveContextSize: Int = resolveContextSize(
            configured: configuration.contextSize,
            slidingWindow: slidingWindow
        )
        let effectiveBatchSize: Int = resolveBatchSize(
            configured: configuration.batchSize,
            contextSize: effectiveContextSize
        )
        let effectiveMicroBatch: Int = resolveMicroBatchSize(
            configured: modelConfiguration.microBatchSize,
            batchSize: effectiveBatchSize
        )

        params.n_ctx = UInt32(effectiveContextSize)
        params.n_batch = UInt32(effectiveBatchSize)
        params.n_ubatch = UInt32(effectiveMicroBatch)
        params.n_threads = Int32(configuration.threadCount)
        params.n_threads_batch = Int32(configuration.threadCount)
    }

    private static func applyExecutionParams(
        modelConfiguration: ComputeConfigurationExtended,
        to params: inout llama_context_params
    ) {
        let kvType: ggml_type = mapKVCacheType(modelConfiguration.kvCacheType)

        params.embeddings = false
        params.flash_attn = modelConfiguration.flashAttention
        params.no_perf = false
        params.offload_kqv = modelConfiguration.offloadKQV
        params.op_offload = modelConfiguration.opOffload
        params.type_k = kvType
        params.type_v = kvType
        params.rope_scaling_type = mapRopeScaling(modelConfiguration.ropeScaling)
        params.rope_freq_base = modelConfiguration.ropeFreqBase ?? 0
        params.rope_freq_scale = modelConfiguration.ropeFreqScale ?? 0
    }

    private static func mapKVCacheType(_ type: KVCacheType) -> ggml_type {
        switch type {
        case .f32:
            return GGML_TYPE_F32

        case .f16:
            return GGML_TYPE_F16

        case .q8_0:
            return GGML_TYPE_Q8_0

        case .q4_0:
            return GGML_TYPE_Q4_0
        }
    }

    private static func mapRopeScaling(_ type: RopeScalingType) -> llama_rope_scaling_type {
        switch type {
        case .noScaling:
            return LLAMA_ROPE_SCALING_TYPE_NONE

        case .linear:
            return LLAMA_ROPE_SCALING_TYPE_LINEAR

        case .yarn:
            return LLAMA_ROPE_SCALING_TYPE_YARN
        }
    }

    private func makeContextParams(model: LlamaCPPModel) -> llama_context_params {
        Self.buildContextParams(
            configuration: configuration,
            modelConfiguration: model.configuration,
            slidingWindow: Int(model.slidingWindow)
        )
    }

    private func createContext(model: LlamaCPPModel) throws -> OpaquePointer {
        guard let modelPointer = model.pointer else {
            throw LLMError.invalidConfiguration("Model has been freed")
        }

        let params: llama_context_params = makeContextParams(model: model)

        // Log context parameters before creation
        Logger.logContextParameters(params)

        // Create the context
        guard let ctx = llama_init_from_model(modelPointer, params) else {
            throw LLMError.invalidConfiguration("Failed to create context")
        }

        return ctx
    }

    deinit {
        // Free resources if not already freed
        if let ctx = pointer {
            llama_free(ctx)
            pointer = nil
        }
    }

    /// Check if the context is loaded
    internal var isLoaded: Bool {
        pointer != nil
    }

    /// Get the actual context size
    internal var contextSize: Int32 {
        guard let ctx = pointer else {
            return 0
        }
        return Int32(llama_n_ctx(ctx))
    }

    /// Get the batch size
    internal var batchSize: Int32 {
        guard let ctx = pointer else {
            return 0
        }
        return Int32(llama_n_batch(ctx))
    }

    /// Reset the context state
    /// - Throws: LlamaCPPError if context is invalid
    internal func reset() throws {
        guard let ctx = pointer else {
            throw LLMError.invalidConfiguration("Context has been freed")
        }
        // Get the memory and clear it
        let memory: OpaquePointer? = llama_get_memory(ctx)
        if let memory {
            llama_memory_clear(memory, false) // false = don't clear data buffers, just metadata
        }
        resetEpoch &+= 1
    }

    /// Free the context and release resources
    internal func free() {
        if let ctx = pointer {
            llama_free(ctx)
            pointer = nil
        }
    }
}
