import Abstractions
import Foundation
import llama

/// Context wrapper for llama.cpp
/// Note: This class is NOT thread-safe and should only be used within LlamaCPPSession actor
internal final class LlamaCPPContext {
    internal private(set) var pointer: OpaquePointer?

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

    private func createContext(model: LlamaCPPModel) throws -> OpaquePointer {
        guard let modelPointer = model.pointer else {
            throw LLMError.invalidConfiguration("Model has been freed")
        }

        // Get default context parameters
        var params: llama_context_params = llama_context_default_params()

        // Apply configuration (convert from Int to appropriate C types)
        params.n_ctx = UInt32(configuration.contextSize)
        params.n_batch = UInt32(configuration.batchSize)
        params.n_threads = Int32(configuration.threadCount)
        params.n_threads_batch = Int32(configuration.threadCount)

        // Set other parameters
        params.embeddings = false
        params.flash_attn = false
        params.no_perf = false
        params.type_k = GGML_TYPE_F16
        params.type_v = GGML_TYPE_F16

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
    }

    /// Free the context and release resources
    internal func free() {
        if let ctx = pointer {
            llama_free(ctx)
            pointer = nil
        }
    }
}
