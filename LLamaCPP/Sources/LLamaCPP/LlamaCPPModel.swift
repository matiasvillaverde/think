import Abstractions
import Darwin
import Foundation
import llama

/// Model wrapper for llama.cpp
/// Note: This class is NOT thread-safe and should only be used within LlamaCPPSession actor
internal final class LlamaCPPModel {
    internal private(set) var pointer: OpaquePointer?

    private let modelPath: String
    private let deviceList: [ggml_backend_dev_t?]

    private struct CachedModel {
        var pointer: OpaquePointer
        var refCount: Int
    }

    private static let cacheLock: NSLock = NSLock()
    nonisolated(unsafe) private static var cachedModels: [String: CachedModel] = [:]

    private static let backendLock: NSLock = NSLock()
    nonisolated(unsafe) private static var backendInitialized: Bool = false

    private static let cpuMicroBatchCap: Int = 64

    private static func environmentFlag(_ name: String) -> Bool {
        guard let rawValue = getenv(name) else {
            return false
        }
        return String(cString: rawValue) == "1"
    }

    private static var shouldUseSharedModelCache: Bool {
        environmentFlag("LLAMA_CPP_TEST_SHARED_MODEL")
    }
    private static var shouldKeepSharedModelLoaded: Bool { shouldUseSharedModelCache }
    private static var shouldForceCPU: Bool { environmentFlag("LLAMA_CPP_FORCE_CPU") }

    /// The configuration used to load this model
    internal let configuration: ComputeConfigurationExtended

    /// Initialize and load a model from file with extended configuration
    /// - Parameters:
    ///   - path: Path to the GGUF model file
    ///   - configuration: Extended compute configuration for GPU and performance settings
    /// - Throws: LlamaCPPError if model cannot be loaded
    internal init(path: String, configuration: ComputeConfigurationExtended) throws {
        guard FileManager.default.fileExists(atPath: path) else {
            throw LLMError.modelNotFound(path)
        }

        Self.ensureBackendInitialized()

        let effectiveConfiguration: ComputeConfigurationExtended = Self.applyForceCPUOverrides(
            configuration
        )

        self.configuration = effectiveConfiguration
        self.modelPath = path
        self.deviceList = Self.makeDeviceListIfNeeded(configuration: effectiveConfiguration)
        self.pointer = try loadModelPointer(path: path, configuration: effectiveConfiguration)
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

    private func loadModelPointer(
        path: String,
        configuration: ComputeConfigurationExtended
    ) throws -> OpaquePointer {
        let params: llama_model_params = Self.buildModelParams(configuration: configuration)
        Logger.logModelParameters(params)
        Logger.logPlatformInfo()

        if deviceList.isEmpty {
            return try Self.loadModelInternal(path: path, params: params)
        }

        return try deviceList.withUnsafeBufferPointer { buffer in
            var paramsWithDevices: llama_model_params = params
            paramsWithDevices.devices = UnsafeMutablePointer(mutating: buffer.baseAddress)
            return try Self.loadModelInternal(path: path, params: paramsWithDevices)
        }
    }

    private static func buildModelParams(
        configuration: ComputeConfigurationExtended
    ) -> llama_model_params {
        var params: llama_model_params = llama_model_default_params()
        applyConfiguration(configuration, to: &params)

        #if targetEnvironment(simulator) // Override only for simulator
        params.n_gpu_layers = 0  // Force CPU-only mode
        params.use_mmap = false  // Sometimes helps with simulator issues
        params.check_tensors = false  // Disable tensor checking if causing issues
        #endif

        return params
    }

    private static func applyConfiguration(
        _ configuration: ComputeConfigurationExtended,
        to params: inout llama_model_params
    ) {
        if configuration.gpuLayers >= 0 {
            params.n_gpu_layers = Int32(configuration.gpuLayers)
        }
        params.split_mode = mapSplitMode(configuration.splitMode)
        params.main_gpu = Int32(configuration.mainGPU)
        params.use_mmap = !shouldForceCPU
        params.use_mlock = configuration.useMlock
    }

    private static func applyForceCPUOverrides(
        _ configuration: ComputeConfigurationExtended
    ) -> ComputeConfigurationExtended {
        guard shouldForceCPU else {
            return configuration
        }
        let microBatchSize: Int = resolveForcedMicroBatchSize(configuration)
        return ComputeConfigurationExtended(
            contextSize: configuration.contextSize,
            batchSize: configuration.batchSize,
            threadCount: configuration.threadCount,
            gpuLayers: 0,
            offloadKQV: false,
            splitMode: .noSplit,
            opOffload: false,
            microBatchSize: microBatchSize,
            kvCacheType: configuration.kvCacheType,
            ropeScaling: configuration.ropeScaling,
            ropeFreqBase: configuration.ropeFreqBase,
            ropeFreqScale: configuration.ropeFreqScale
        )
    }
    private static func resolveForcedMicroBatchSize(
        _ configuration: ComputeConfigurationExtended
    ) -> Int {
        let baseSize: Int = configuration.microBatchSize ?? configuration.batchSize
        return max(1, min(baseSize, cpuMicroBatchCap))
    }

    private static func makeDeviceListIfNeeded(
        configuration: ComputeConfigurationExtended
    ) -> [ggml_backend_dev_t?] {
        guard shouldUseCPUDevices(configuration: configuration) else {
            return []
        }
        guard let cpuDevice: ggml_backend_dev_t = ggml_backend_dev_by_type(
            GGML_BACKEND_DEVICE_TYPE_CPU
        ) else {
            return []
        }
        return [cpuDevice, nil]
    }

    private static func shouldUseCPUDevices(configuration: ComputeConfigurationExtended) -> Bool {
        shouldForceCPU
            || (configuration.gpuLayers == 0
                && !configuration.offloadKQV
                && !configuration.opOffload)
    }

    private static func loadModelInternal(
        path: String,
        params: llama_model_params
    ) throws -> OpaquePointer {
        if shouldUseSharedModelCache {
            cacheLock.lock()
            if var cached = cachedModels[path] {
                cached.refCount += 1
                cachedModels[path] = cached
                cacheLock.unlock()
                return cached.pointer
            }
            cacheLock.unlock()
        }

        guard let model = llama_model_load_from_file(path, params) else {
            throw LLMError.modelNotFound("Failed to load model from \(path)")
        }

        if shouldUseSharedModelCache {
            cacheLock.lock()
            cachedModels[path] = CachedModel(pointer: model, refCount: 1)
            cacheLock.unlock()
        }

        return model
    }

    internal static func ensureBackendInitialized() {
        backendLock.lock()
        defer { backendLock.unlock() }

        guard !backendInitialized else {
            return
        }

        llama_backend_init()
        atexit {
            llama_backend_free()
        }
        backendInitialized = true
    }

    private func shouldFreeSharedModel(for path: String) -> Bool {
        Self.cacheLock.lock()
        defer { Self.cacheLock.unlock() }

        guard var cached = Self.cachedModels[path] else {
            return true
        }

        cached.refCount -= 1
        if cached.refCount <= 0 {
            if Self.shouldKeepSharedModelLoaded {
                cached.refCount = 1
                Self.cachedModels[path] = cached
                return false
            }
            Self.cachedModels.removeValue(forKey: path)
            return true
        }

        Self.cachedModels[path] = cached
        return false
    }

    private func releaseModel() {
        guard let model = pointer else {
            return
        }

        if Self.shouldUseSharedModelCache {
            if shouldFreeSharedModel(for: modelPath) {
                llama_model_free(model)
            }
        } else {
            llama_model_free(model)
        }

        pointer = nil
    }

    /// Map SplitMode enum to llama.cpp's split mode
    private static func mapSplitMode(_ mode: SplitMode) -> llama_split_mode {
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

    /// Get the model's sliding window attention size (0 if not applicable)
    internal var slidingWindow: Int32 {
        guard let model = pointer else {
            return 0
        }
        return llama_model_n_swa(model)
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
        releaseModel()
    }

    deinit {
        // Free resources if not already freed
        releaseModel()
    }
}
