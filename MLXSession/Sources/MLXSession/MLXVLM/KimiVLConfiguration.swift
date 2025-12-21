import Foundation

internal struct KimiVLConfiguration: Decodable, Sendable {
    internal let textConfig: DeepseekV3Configuration
    internal let visionConfig: KimiVLVisionConfiguration
    internal let modelType: String
    internal let ignoreIndex: Int
    internal let vocabSize: Int
    internal let scaleFactor: Int
    internal let mediaPlaceholderTokenId: Int
    internal let imageTokenIndex: Int
    internal let eosTokenId: [Int]?

    enum CodingKeys: String, CodingKey {
        case textConfig = "text_config"
        case visionConfig = "vision_config"
        case modelType = "model_type"
        case ignoreIndex = "ignore_index"
        case vocabSize = "vocab_size"
        case scaleFactor = "scale_factor"
        case mediaPlaceholderTokenId = "media_placeholder_token_id"
        case imageTokenIndex = "image_token_index"
        case eosTokenId = "eos_token_id"
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.textConfig = try container.decode(DeepseekV3Configuration.self, forKey: .textConfig)
        self.visionConfig = try container.decode(KimiVLVisionConfiguration.self, forKey: .visionConfig)
        self.modelType = try container.decode(String.self, forKey: .modelType)
        self.ignoreIndex = try container.decodeIfPresent(Int.self, forKey: .ignoreIndex) ?? -100
        self.vocabSize = try container.decodeIfPresent(Int.self, forKey: .vocabSize) ?? textConfig.vocabSize
        self.scaleFactor = try container.decodeIfPresent(Int.self, forKey: .scaleFactor) ?? 2
        self.mediaPlaceholderTokenId = try container.decodeIfPresent(
            Int.self,
            forKey: .mediaPlaceholderTokenId
        ) ?? 0
        let imageToken = try container.decodeIfPresent(Int.self, forKey: .imageTokenIndex)
        self.imageTokenIndex = imageToken ?? self.mediaPlaceholderTokenId
        self.eosTokenId = try container.decodeIfPresent(IntOrIntArray.self, forKey: .eosTokenId)?.values
    }
}

internal struct KimiVLVisionConfiguration: Decodable, Sendable {
    internal let modelType: String
    internal let depth: Int
    internal let embedDim: Int
    internal let hiddenSize: Int
    internal let numHeads: Int
    internal let imageSize: Int
    internal let patchSize: Int
    internal let vocabSize: Int
    internal let mlpRatio: Float
    internal let numChannels: Int
    internal let layerNormEps: Float
    internal let intermediateSize: Int
    internal let initPosEmbHeight: Int
    internal let initPosEmbWidth: Int
    internal let spatialPatchSize: Int
    internal let spatialMergeSize: Int
    internal let temporalPatchSize: Int
    internal let mergeKernelSize: [Int]

    enum CodingKeys: String, CodingKey {
        case modelType = "model_type"
        case depth = "depth"
        case numHiddenLayers = "num_hidden_layers"
        case embedDim = "embed_dim"
        case hiddenSize = "hidden_size"
        case numHeads = "num_heads"
        case numAttentionHeads = "num_attention_heads"
        case imageSize = "image_size"
        case patchSize = "patch_size"
        case vocabSize = "vocab_size"
        case mlpRatio = "mlp_ratio"
        case numChannels = "num_channels"
        case layerNormEps = "layer_norm_eps"
        case intermediateSize = "intermediate_size"
        case initPosEmbHeight = "init_pos_emb_height"
        case initPosEmbWidth = "init_pos_emb_width"
        case spatialPatchSize = "spatial_patch_size"
        case spatialMergeSize = "spatial_merge_size"
        case temporalPatchSize = "temporal_patch_size"
        case mergeKernelSize = "merge_kernel_size"
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.modelType = try container.decodeIfPresent(String.self, forKey: .modelType) ?? "moonvit"

        let depth = try container.decodeIfPresent(Int.self, forKey: .depth)
        let numHiddenLayers = try container.decodeIfPresent(Int.self, forKey: .numHiddenLayers)
        self.depth = depth ?? numHiddenLayers ?? 27

        self.hiddenSize = try container.decodeIfPresent(Int.self, forKey: .hiddenSize) ?? 1152
        let embedDim = try container.decodeIfPresent(Int.self, forKey: .embedDim)
        self.embedDim = embedDim ?? hiddenSize

        let numHeads = try container.decodeIfPresent(Int.self, forKey: .numHeads)
        let numAttentionHeads = try container.decodeIfPresent(Int.self, forKey: .numAttentionHeads)
        self.numHeads = numHeads ?? numAttentionHeads ?? 16

        self.imageSize = try container.decodeIfPresent(Int.self, forKey: .imageSize) ?? 384
        self.patchSize = try container.decodeIfPresent(Int.self, forKey: .patchSize) ?? 14
        self.vocabSize = try container.decodeIfPresent(Int.self, forKey: .vocabSize) ?? 32_000
        self.mlpRatio = try container.decodeIfPresent(Float.self, forKey: .mlpRatio) ?? 4.0
        self.numChannels = try container.decodeIfPresent(Int.self, forKey: .numChannels) ?? 3
        self.layerNormEps = try container.decodeIfPresent(Float.self, forKey: .layerNormEps) ?? 1e-6
        self.intermediateSize = try container.decodeIfPresent(
            Int.self,
            forKey: .intermediateSize
        ) ?? 4_304
        self.initPosEmbHeight = try container.decodeIfPresent(
            Int.self,
            forKey: .initPosEmbHeight
        ) ?? 64
        self.initPosEmbWidth = try container.decodeIfPresent(
            Int.self,
            forKey: .initPosEmbWidth
        ) ?? 64
        self.spatialPatchSize = try container.decodeIfPresent(
            Int.self,
            forKey: .spatialPatchSize
        ) ?? patchSize
        self.spatialMergeSize = try container.decodeIfPresent(
            Int.self,
            forKey: .spatialMergeSize
        ) ?? 2
        self.temporalPatchSize = try container.decodeIfPresent(
            Int.self,
            forKey: .temporalPatchSize
        ) ?? 2
        if let mergeKernelSize = try container.decodeIfPresent([Int].self, forKey: .mergeKernelSize) {
            self.mergeKernelSize = mergeKernelSize
        } else {
            self.mergeKernelSize = [spatialMergeSize, spatialMergeSize]
        }
    }
}

internal struct KimiVLProcessorConfiguration: Decodable, Sendable {
    internal let patchSize: Int
    internal let padInput: Bool
    internal let imageMean: [Float]
    internal let imageStd: [Float]
    internal let inTokenLimit: Int
    internal let mergeKernelSize: [Int]
    internal let processorClass: String

    enum CodingKeys: String, CodingKey {
        case patchSize = "patch_size"
        case padInput = "pad_input"
        case imageMean = "image_mean"
        case imageStd = "image_std"
        case inTokenLimit = "in_token_limit"
        case mergeKernelSize = "merge_kernel_size"
        case processorClass = "processor_class"
    }
}

internal enum IntOrIntArray: Codable, Sendable {
    case int(Int)
    case array([Int])

    internal var values: [Int] {
        switch self {
        case .int(let value):
            return [value]
        case .array(let value):
            return value
        }
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let value = try? container.decode(Int.self) {
            self = .int(value)
        } else {
            self = .array(try container.decode([Int].self))
        }
    }

    func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .int(let value):
            try container.encode(value)
        case .array(let value):
            try container.encode(value)
        }
    }
}
