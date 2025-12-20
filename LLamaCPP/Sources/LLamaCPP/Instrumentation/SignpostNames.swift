import Foundation

/// Signpost names for consistent instrumentation
internal enum SignpostNames {
    /// Model operations
    internal static let modelLoad: StaticString = "Model Load"
    internal static let modelUnload: StaticString = "Model Unload"

    /// Context operations
    internal static let contextCreate: StaticString = "Context Create"
    internal static let contextReset: StaticString = "Context Reset"

    /// Generation pipeline
    internal static let streamGeneration: StaticString = "Stream Generation"
    internal static let promptTokenization: StaticString = "Prompt Tokenization"
    internal static let promptProcessing: StaticString = "Prompt Processing"
    internal static let tokenGeneration: StaticString = "Token Generation"
    internal static let tokenSampling: StaticString = "Token Sampling"
    internal static let tokenDecoding: StaticString = "Token Decoding"

    /// Batch operations
    internal static let batchProcessing: StaticString = "Batch Processing"
    internal static let batchEvaluation: StaticString = "Batch Evaluation"

    /// Memory operations
    internal static let kvCacheClear: StaticString = "KV Cache Clear"
    internal static let memoryAllocation: StaticString = "Memory Allocation"
}
