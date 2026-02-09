import Abstractions
import Foundation

/// Language model configuration from config.json
internal struct LanguageModelConfiguration: Codable, Sendable {
    // Core model information
    internal let modelType: String?
    internal let architectures: [String]?

    // Model dimensions
    internal let vocabSize: Int?
    internal let hiddenSize: Int?
    internal let intermediateSize: Int?
    internal let numHiddenLayers: Int?
    internal let numAttentionHeads: Int?
    internal let numKeyValueHeads: Int?

    // Normalization parameters
    internal let rmsNormEps: Double?
    internal let layerNormEps: Double?
    internal let layerNormEpsilon: Double?

    // Position embedding configuration
    internal let maxPositionEmbeddings: Int?
    internal let ropeScaling: RopeScaling?
    internal let ropeTheta: Double?

    // Token IDs
    internal let bosTokenId: Int?
    internal let eosTokenId: Int?
    internal let padTokenId: Int?
    internal let unkTokenId: Int?
    internal let sepTokenId: Int?
    internal let clsTokenId: Int?
    internal let maskTokenId: Int?

    // Model behavior
    private let _tieWordEmbeddings: Bool? // swiftlint:disable:this discouraged_optional_boolean
    private let _useCache: Bool? // swiftlint:disable:this discouraged_optional_boolean

    internal var tieWordEmbeddings: Bool {
        _tieWordEmbeddings ?? false
    }

    internal var useCache: Bool {
        _useCache ?? true
    }

    // Training configuration
    internal let torchDtype: String?
    internal let transformersVersion: String?

    // Additional fields for specific architectures
    internal let hiddenAct: String?
    internal let hiddenDropout: Double?
    internal let attentionDropout: Double?
    internal let initializerRange: Double?
    internal let typeVocabSize: Int?

    // GPT-specific
    internal let nEmbd: Int?
    internal let nLayer: Int?
    internal let nHead: Int?
    internal let nCtx: Int?

    // Mistral/Mixtral specific
    internal let slidingWindow: Int?
    internal let numLocalExperts: Int?
    internal let numExpertsPerTok: Int?

    private enum CodingKeys: String, CodingKey {
        case modelType = "model_type"
        case architectures = "architectures"
        case vocabSize = "vocab_size"
        case hiddenSize = "hidden_size"
        case intermediateSize = "intermediate_size"
        case numHiddenLayers = "num_hidden_layers"
        case numAttentionHeads = "num_attention_heads"
        case numKeyValueHeads = "num_key_value_heads"
        case rmsNormEps = "rms_norm_eps"
        case layerNormEps = "layer_norm_eps"
        case layerNormEpsilon = "layer_norm_epsilon"
        case maxPositionEmbeddings = "max_position_embeddings"
        case ropeScaling = "rope_scaling"
        case ropeTheta = "rope_theta"
        case bosTokenId = "bos_token_id"
        case eosTokenId = "eos_token_id"
        case padTokenId = "pad_token_id"
        case unkTokenId = "unk_token_id"
        case sepTokenId = "sep_token_id"
        case clsTokenId = "cls_token_id"
        case maskTokenId = "mask_token_id"
        case _tieWordEmbeddings = "tie_word_embeddings" // swiftlint:disable:this identifier_name
        case _useCache = "use_cache" // swiftlint:disable:this identifier_name
        case torchDtype = "torch_dtype"
        case transformersVersion = "transformers_version"
        case hiddenAct = "hidden_act"
        case hiddenDropout = "hidden_dropout"
        case attentionDropout = "attention_dropout"
        case initializerRange = "initializer_range"
        case typeVocabSize = "type_vocab_size"
        case nEmbd = "n_embd"
        case nLayer = "n_layer"
        case nHead = "n_head"
        case nCtx = "n_ctx"
        case slidingWindow = "sliding_window"
        case numLocalExperts = "num_local_experts"
        case numExpertsPerTok = "num_experts_per_tok"
    }

    internal init(
        modelType: String? = nil,
        architectures: [String]? = nil,
        vocabSize: Int? = nil,
        hiddenSize: Int? = nil,
        intermediateSize: Int? = nil,
        numHiddenLayers: Int? = nil,
        numAttentionHeads: Int? = nil,
        numKeyValueHeads: Int? = nil,
        rmsNormEps: Double? = nil,
        layerNormEps: Double? = nil,
        layerNormEpsilon: Double? = nil,
        maxPositionEmbeddings: Int? = nil,
        ropeScaling: RopeScaling? = nil,
        ropeTheta: Double? = nil,
        bosTokenId: Int? = nil,
        eosTokenId: Int? = nil,
        padTokenId: Int? = nil,
        unkTokenId: Int? = nil,
        sepTokenId: Int? = nil,
        clsTokenId: Int? = nil,
        maskTokenId: Int? = nil,
        tieWordEmbeddings: Bool? = nil, // swiftlint:disable:this discouraged_optional_boolean
        useCache: Bool? = nil, // swiftlint:disable:this discouraged_optional_boolean
        torchDtype: String? = nil,
        transformersVersion: String? = nil,
        hiddenAct: String? = nil,
        hiddenDropout: Double? = nil,
        attentionDropout: Double? = nil,
        initializerRange: Double? = nil,
        typeVocabSize: Int? = nil,
        nEmbd: Int? = nil,
        nLayer: Int? = nil,
        nHead: Int? = nil,
        nCtx: Int? = nil,
        slidingWindow: Int? = nil,
        numLocalExperts: Int? = nil,
        numExpertsPerTok: Int? = nil
    ) {
        self.modelType = modelType
        self.architectures = architectures
        self.vocabSize = vocabSize
        self.hiddenSize = hiddenSize
        self.intermediateSize = intermediateSize
        self.numHiddenLayers = numHiddenLayers
        self.numAttentionHeads = numAttentionHeads
        self.numKeyValueHeads = numKeyValueHeads
        self.rmsNormEps = rmsNormEps
        self.layerNormEps = layerNormEps
        self.layerNormEpsilon = layerNormEpsilon
        self.maxPositionEmbeddings = maxPositionEmbeddings
        self.ropeScaling = ropeScaling
        self.ropeTheta = ropeTheta
        self.bosTokenId = bosTokenId
        self.eosTokenId = eosTokenId
        self.padTokenId = padTokenId
        self.unkTokenId = unkTokenId
        self.sepTokenId = sepTokenId
        self.clsTokenId = clsTokenId
        self.maskTokenId = maskTokenId
        self._tieWordEmbeddings = tieWordEmbeddings
        self._useCache = useCache
        self.torchDtype = torchDtype
        self.transformersVersion = transformersVersion
        self.hiddenAct = hiddenAct
        self.hiddenDropout = hiddenDropout
        self.attentionDropout = attentionDropout
        self.initializerRange = initializerRange
        self.typeVocabSize = typeVocabSize
        self.nEmbd = nEmbd
        self.nLayer = nLayer
        self.nHead = nHead
        self.nCtx = nCtx
        self.slidingWindow = slidingWindow
        self.numLocalExperts = numLocalExperts
        self.numExpertsPerTok = numExpertsPerTok
    }
}

/// Rope scaling configuration
internal struct RopeScaling: Codable, Sendable {
    internal let type: String?
    internal let factor: Double?

    private enum CodingKeys: String, CodingKey {
        case type = "type"
        case factor = "factor"
    }
}

/// Configuration loader from HuggingFace Hub
internal actor LanguageModelConfigurationFromHub {
    private let hubAPI: HubAPI
    private let tokenManager: HFTokenManager

    internal init(hubAPI: HubAPI, tokenManager: HFTokenManager? = nil) {
        self.hubAPI = hubAPI
        self.tokenManager = tokenManager ?? HFTokenManager()
    }

    private func buildAuthHeaders() async -> [String: String] {
        var headers: [String: String] = [:]

        if let token = await tokenManager.getToken() {
            headers["Authorization"] = "Bearer \(token)"
        }

        return headers
    }

    /// Load model configuration from repository
    /// - Parameters:
    ///   - modelId: Model repository ID
    ///   - revision: Git revision (branch, tag, or commit)
    /// - Returns: Parsed configuration
    internal func loadConfiguration(
        modelId: String,
        revision: String = "main"
    ) async throws -> LanguageModelConfiguration {
        let repo: Repository = Repository(id: modelId)

        // Download config.json
        let configURL: URL = repo.downloadURL(path: "config.json", revision: revision)

        // Get auth headers
        let headers: [String: String] = await buildAuthHeaders()

        // Download using HubAPI's HTTP client
        let response: HTTPClientResponse = try await hubAPI.httpGet(url: configURL, headers: headers)

        guard response.statusCode == 200 else {
            if response.statusCode == 404 {
                throw HuggingFaceError.fileNotFound
            }
            throw HuggingFaceError.httpError(statusCode: response.statusCode)
        }

        let data: Data = response.data

        // Parse configuration
        let decoder: JSONDecoder = JSONDecoder()
        return try decoder.decode(LanguageModelConfiguration.self, from: data)
    }
}

/// Model validation result
internal struct ModelValidationResult: Sendable {
    internal let isCompatible: Bool
    internal let errors: [String]
    internal let warnings: [String]

    internal init(isCompatible: Bool, errors: [String] = [], warnings: [String] = []) {
        self.isCompatible = isCompatible
        self.errors = errors
        self.warnings = warnings
    }
}

/// Model validator for compatibility checks
internal actor ModelValidator {
    private let supportedModelTypes: [String] = [
        "llama", "mistral", "mixtral", "phi", "qwen2", "gemma", "gpt2",
        "gpt_neox", "falcon", "mpt", "opt", "bloom", "codegen", "stablelm"
    ]

    private let supportedArchitectures: [String] = [
        "LlamaForCausalLM", "MistralForCausalLM", "MixtralForCausalLM",
        "PhiForCausalLM", "Phi3ForCausalLM", "Phi4ForCausalLM",
        "Qwen2ForCausalLM", "Qwen2VLForCausalLM",
        "GemmaForCausalLM", "Gemma2ForCausalLM",
        "GPT2LMHeadModel", "GPTNeoXForCausalLM", "FalconForCausalLM",
        "MPTForCausalLM", "OPTForCausalLM", "BloomForCausalLM",
        "CodeGenForCausalLM", "StableLMForCausalLM"
    ]

    internal init() {}

    /// Validate model compatibility with format
    /// - Parameters:
    ///   - configuration: Model configuration
    ///   - format: Target model format
    /// - Returns: Validation result with errors and warnings
    internal func validateModel(
        configuration: LanguageModelConfiguration,
        backend: SendableModel.Backend
    ) -> ModelValidationResult {
        var errors: [String] = []
        var warnings: [String] = []

        // Check model type
        if let modelType = configuration.modelType {
            if !supportedModelTypes.contains(modelType) {
                errors.append("Unsupported model type: \(modelType)")
            }
        } else {
            warnings.append("Model type not specified in configuration")
        }

        // Check architecture
        if let architectures = configuration.architectures, !architectures.isEmpty {
            let supportedArch: String? = architectures.first { supportedArchitectures.contains($0) }
            if supportedArch == nil {
                let message: String = "Unsupported architecture: \(architectures.joined(separator: ", "))"
                // GGUF can often run "unknown" transformer families via llama.cpp; treat as warning.
                if backend == .gguf {
                    warnings.append(message)
                } else {
                    errors.append(message)
                }
            }
        } else {
            warnings.append("Architecture not specified in configuration")
        }

        // Backend-specific checks
        switch backend {
        case .mlx:
            // MLX specific requirements
            if configuration.hiddenSize == nil || configuration.numHiddenLayers == nil {
                errors.append("MLX format requires hidden_size and num_hidden_layers")
            }

        case .gguf:
            // GGUF can handle most models
            if configuration.vocabSize == nil {
                errors.append("GGUF format requires vocab_size")
            }

        case .coreml:
            // CoreML specific checks
            if configuration.vocabSize == nil || configuration.hiddenSize == nil {
                errors.append("CoreML format requires vocab_size and hidden_size")
            }

        case .remote:
            // Remote models don't need local file validation
            break
        }

        // Check for potential issues
        if let maxPos = configuration.maxPositionEmbeddings, maxPos > 32_768 {
            warnings.append("Large context length (\(maxPos)) may require significant memory")
        }

        if let dtype = configuration.torchDtype, dtype == "float32" {
            warnings.append("Model uses float32, consider quantized versions for better performance")
        }

        return ModelValidationResult(
            isCompatible: errors.isEmpty,
            errors: errors,
            warnings: warnings
        )
    }
}

/// Model metadata extractor
internal actor ModelMetadataExtractor {
    internal init() {}

    /// Extract metadata from model configuration and files
    /// - Parameters:
    ///   - configuration: Model configuration
    ///   - files: List of model files
    ///   - modelId: Model repository ID
    /// - Returns: Extracted metadata
    internal func extractMetadata(
        configuration: LanguageModelConfiguration,
        files: [FileInfo],
        modelId: String
    ) -> ModelMetadata {
        let modelType: String = configuration.modelType ?? "unknown"
        let architecture: String = configuration.architectures?.first ?? "unknown"

        // Calculate total size
        let totalSize: Int64 = files.reduce(0) { $0 + $1.size }

        // Estimate parameters based on model dimensions
        let parameters: String = estimateParameters(configuration: configuration)

        // Extract quantization from filename patterns
        let quantization: String? = detectQuantization(files: files)

        // Get context length
        let contextLength: Int? = configuration.maxPositionEmbeddings

        return ModelMetadata(
            modelId: modelId,
            modelType: modelType,
            architecture: architecture,
            parameters: parameters,
            totalSize: totalSize,
            quantization: quantization,
            contextLength: contextLength
        )
    }

    private func estimateParameters(configuration: LanguageModelConfiguration) -> String {
        guard let hiddenSize = configuration.hiddenSize ?? configuration.nEmbd,
              let numLayers = configuration.numHiddenLayers ?? configuration.nLayer else {
            return "unknown"
        }

        // Rough parameter estimation based on transformer architecture
        let vocabSize: Int = configuration.vocabSize ?? 50_000
        let intermediateSize: Int = configuration.intermediateSize ?? (hiddenSize * 4)

        // Embedding and output parameters
        let embeddingParams: Int = vocabSize * hiddenSize
        let outputParams: Int = vocabSize * hiddenSize // LM head

        // Attention parameters per layer
        let numHeads: Int = configuration.numAttentionHeads ?? configuration.nHead ?? 12
        let headDim: Int = hiddenSize / numHeads
        let kvHeads: Int = configuration.numKeyValueHeads ?? numHeads
        let qParams: Int = hiddenSize * hiddenSize
        let kParams: Int = (hiddenSize * headDim * kvHeads)
        let vParams: Int = (hiddenSize * headDim * kvHeads)
        let oParams: Int = hiddenSize * hiddenSize
        let attentionParams: Int = qParams + kParams + vParams + oParams

        // FFN parameters per layer
        let ffnUpParams: Int = hiddenSize * intermediateSize
        let ffnDownParams: Int = intermediateSize * hiddenSize
        let ffnParams: Int = ffnUpParams + ffnDownParams

        // Layer norm parameters per layer (2 per layer: attention and FFN)
        let layerNormParams: Int = hiddenSize * 2

        // Total layer parameters
        let layerParams: Int = attentionParams + ffnParams + layerNormParams

        // Total parameters
        let totalParams: Int = embeddingParams + outputParams + (layerParams * numLayers)

        // Convert to human-readable format with rounding
        let billion: Int = 1_000_000_000
        let million: Int = 1_000_000

        if totalParams >= billion {
            let billions: Double = Double(totalParams) / Double(billion)
            // Round to nearest common size (1B, 3B, 7B, 13B, 30B, 65B, etc.)
            if billions < 2 {
                return "1B"
            }
            if billions < 5 {
                return "3B"
            }
            if billions < 10 {
                return "7B"
            }
            if billions < 20 {
                return "13B"
            }
            if billions < 40 {
                return "30B"
            }
            if billions < 100 {
                return "65B"
            }
            return "\(Int(billions))B"
        }
        return "\(totalParams / million)M"
    }

    private func detectQuantization(files: [FileInfo]) -> String? {
        for file in files {
            let filename: String = file.path.lowercased()

            // Check for common quantization patterns
            if filename.contains("q4_0") || filename.contains("4bit") {
                return "Q4_0"
            }
            if filename.contains("q4_1") {
                return "Q4_1"
            }
            if filename.contains("q5_0") || filename.contains("5bit") {
                return "Q5_0"
            }
            if filename.contains("q5_1") {
                return "Q5_1"
            }
            if filename.contains("q8_0") || filename.contains("8bit") {
                return "Q8_0"
            }
            if filename.contains("fp16") || filename.contains("f16") {
                return "FP16"
            }
            if filename.contains("int8") {
                return "INT8"
            }
            if filename.contains("int4") {
                return "INT4"
            }
        }

        return nil
    }
}

/// Model metadata
internal struct ModelMetadata: Sendable {
    internal let modelId: String
    internal let modelType: String
    internal let architecture: String
    internal let parameters: String
    internal let totalSize: Int64
    internal let quantization: String?
    internal let contextLength: Int?
}
