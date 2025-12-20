import Abstractions
import Foundation
import llama

/// Model wrapper for llama.cpp
/// Note: This class is NOT thread-safe and should only be used within LlamaCPPSession actor
internal final class LlamaCPPModel {
    internal private(set) var pointer: OpaquePointer?

    /// The configuration used to load this model
    internal let configuration: ComputeConfigurationExtended

    /// Initialize and load a model from file with extended configuration
    /// - Parameters:
    ///   - path: Path to the GGUF model file
    ///   - configuration: Extended compute configuration for GPU and performance settings
    /// - Throws: LlamaCPPError if model cannot be loaded
    internal init(path: String, configuration: ComputeConfigurationExtended) throws {
        // Check if file exists
        guard FileManager.default.fileExists(atPath: path) else {
            throw LLMError.modelNotFound(path)
        }

        self.configuration = configuration

        // Get default model parameters
        var params: llama_model_params = llama_model_default_params()

        // Apply extended configuration
        // params.n_gpu_layers = Int32(configuration.gpuLayers) It works faster without it -1 is wrong.
        params.split_mode = mapSplitMode(configuration.splitMode)
        params.main_gpu = Int32(configuration.mainGPU)
        params.use_mmap = true
        params.use_mlock = configuration.useMlock

        #if targetEnvironment(simulator) // Override only for simulator
        params.n_gpu_layers = 0  // Force CPU-only mode
        params.use_mmap = false  // Sometimes helps with simulator issues
        params.check_tensors = false  // Disable tensor checking if causing issues
        #endif

        // Log model parameters before loading
        Logger.logModelParameters(params)
        Logger.logPlatformInfo()  // Log platform info once during model load

        // Load the model
        guard let model = llama_model_load_from_file(path, params) else {
            throw LLMError.modelNotFound("Failed to load model from \(path)")
        }

        self.pointer = model
    }

    /// Initialize and load a model from file with basic configuration (backward compatibility)
    /// - Parameters:
    ///   - path: Path to the GGUF model file
    ///   - configuration: Basic compute configuration
    /// - Throws: LlamaCPPError if model cannot be loaded
    internal convenience init(path: String, configuration: ComputeConfiguration) throws {
        let extended: ComputeConfigurationExtended = ComputeConfigurationExtended(
            from: configuration,
            gpuEnabled: true
        )
        try self.init(path: path, configuration: extended)
    }

    /// Initialize with auto-detected platform configuration
    /// - Parameter path: Path to the GGUF model file
    /// - Throws: LlamaCPPError if model cannot be loaded
    internal convenience init(path: String) throws {
        let extended: ComputeConfigurationExtended = ComputeConfigurationExtended
            .optimizedForCurrentDevice()
        try self.init(path: path, configuration: extended)
    }

    /// Map SplitMode enum to llama.cpp's split mode
    private func mapSplitMode(_ mode: SplitMode) -> llama_split_mode {
        switch mode {
        case .noSplit:
            return LLAMA_SPLIT_MODE_NONE

        case .layer:
            return LLAMA_SPLIT_MODE_LAYER

        case .row:
            return LLAMA_SPLIT_MODE_ROW
        }
    }

    /// Check if the model is loaded
    internal var isLoaded: Bool {
        pointer != nil
    }

    /// Get the vocabulary size of the model
    internal var vocabSize: Int32 {
        guard let model = pointer else {
            return 0
        }
        guard let vocab = llama_model_get_vocab(model) else {
            return 0
        }
        return llama_vocab_n_tokens(vocab)
    }

    /// Get the context length the model was trained on
    internal var contextLength: Int32 {
        guard let model = pointer else {
            return 0
        }
        return llama_model_n_ctx_train(model)
    }

    /// Get the embedding size of the model
    internal var embeddingSize: Int32 {
        guard let model = pointer else {
            return 0
        }
        return llama_model_n_embd(model)
    }

    /// Free the model and release resources
    internal func free() {
        if let model = pointer {
            llama_model_free(model)
            pointer = nil
        }
    }

    deinit {
        // Free resources if not already freed
        if let model = pointer {
            llama_model_free(model)
            pointer = nil
        }
    }
}
