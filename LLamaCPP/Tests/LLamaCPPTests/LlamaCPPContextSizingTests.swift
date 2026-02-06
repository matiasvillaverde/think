import Abstractions
import llama
@testable import LLamaCPP
import Testing

extension LlamaCPPModelTestSuite {
    @Test("Context size honors sliding window")
    internal func testResolveContextSizeHonorsSlidingWindow() {
        #expect(LlamaCPPContext.resolveContextSize(configured: 2_048, slidingWindow: 4_096) == 4_096)
        #expect(LlamaCPPContext.resolveContextSize(configured: 4_096, slidingWindow: 2_048) == 4_096)
    }

    @Test("Context size clamps to positive")
    internal func testResolveContextSizeClampsPositive() {
        #expect(LlamaCPPContext.resolveContextSize(configured: 0, slidingWindow: 0) == 1)
        #expect(LlamaCPPContext.resolveContextSize(configured: -5, slidingWindow: 32) == 32)
    }

    @Test("Batch size clamps to context")
    internal func testResolveBatchSizeClampsToContext() {
        #expect(LlamaCPPContext.resolveBatchSize(configured: 512, contextSize: 128) == 128)
        #expect(LlamaCPPContext.resolveBatchSize(configured: 64, contextSize: 128) == 64)
        #expect(LlamaCPPContext.resolveBatchSize(configured: 0, contextSize: 128) == 1)
    }

    @Test("Micro batch size clamps to batch")
    internal func testResolveMicroBatchSizeClampsToBatch() {
        #expect(LlamaCPPContext.resolveMicroBatchSize(configured: nil, batchSize: 64) == 64)
        #expect(LlamaCPPContext.resolveMicroBatchSize(configured: 32, batchSize: 64) == 32)
        #expect(LlamaCPPContext.resolveMicroBatchSize(configured: 128, batchSize: 64) == 64)
        #expect(LlamaCPPContext.resolveMicroBatchSize(configured: 0, batchSize: 64) == 1)
    }

    @Test("Context params honor model configuration")
    internal func testBuildContextParamsHonorsModelConfiguration() {
        let compute: ComputeConfiguration = ComputeConfiguration(
            contextSize: 2_048,
            batchSize: 128,
            threadCount: 4
        )
        let modelConfig: ComputeConfigurationExtended = ComputeConfigurationExtended(
            contextSize: 2_048,
            batchSize: 128,
            threadCount: 4,
            gpuLayers: 0,
            offloadKQV: false,
            splitMode: .noSplit,
            mainGPU: 0,
            opOffload: false,
            microBatchSize: 32,
            flashAttention: true,
            kvCacheType: .q8_0,
            useMlock: false,
            ropeScaling: .linear,
            ropeFreqBase: 10.0,
            ropeFreqScale: 2.0
        )

        let params: llama_context_params = LlamaCPPContext.buildContextParams(
            configuration: compute,
            modelConfiguration: modelConfig,
            slidingWindow: 0
        )

        #expect(params.n_batch == UInt32(128))
        #expect(params.n_ubatch == UInt32(32))
        #expect(params.offload_kqv == false)
        #expect(params.op_offload == false)
        #expect(params.flash_attn == true)
        #expect(params.type_k == GGML_TYPE_Q8_0)
        #expect(params.type_v == GGML_TYPE_Q8_0)
        #expect(params.rope_scaling_type == LLAMA_ROPE_SCALING_TYPE_LINEAR)
        #expect(params.rope_freq_base == Float(10))
        #expect(params.rope_freq_scale == Float(2))
    }
}
