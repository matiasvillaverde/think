import Foundation
import MLX
import MLXNN

private final class KimiVLMultiModalProjector: Module {
    let hiddenSize: Int

    @ModuleInfo(key: "pre_norm") var preNorm: LayerNorm
    @ModuleInfo(key: "linear_1") var linear1: Linear
    @ModuleInfo(key: "linear_2") var linear2: Linear
    @ModuleInfo var act: GELU

    init(config: KimiVLConfiguration) {
        self.hiddenSize = config.visionConfig.hiddenSize
            * config.visionConfig.mergeKernelSize[0]
            * config.visionConfig.mergeKernelSize[1]
        self._preNorm.wrappedValue = LayerNorm(
            dimensions: config.visionConfig.hiddenSize,
            eps: 1e-5
        )
        self._linear1.wrappedValue = Linear(hiddenSize, hiddenSize, bias: true)
        self._linear2.wrappedValue = Linear(hiddenSize, config.textConfig.hiddenSize, bias: true)
        self.act = GELU()
    }

    func callAsFunction(_ imageFeatures: [MLXArray]) -> MLXArray {
        let concatenatedFeatures = concatenated(imageFeatures, axis: 0)
        var hidden = preNorm(concatenatedFeatures).reshaped(-1, hiddenSize)
        hidden = linear1(hidden)
        hidden = act(hidden)
        hidden = linear2(hidden)
        return hidden
    }
}

internal final class KimiVLModel: Module, VLMModel, KVCacheDimensionProvider {
    @ModuleInfo(key: "vision_tower") private var visionTower: KimiVLVisionModel
    @ModuleInfo(key: "language_model") private var languageModel: DeepseekV3Model
    @ModuleInfo(key: "multi_modal_projector") private var multiModalProjector: KimiVLMultiModalProjector

    internal let config: KimiVLConfiguration
    internal var kvHeads: [Int]

    init(_ config: KimiVLConfiguration) {
        self.config = config
        self._visionTower.wrappedValue = KimiVLVisionModel(config.visionConfig)
        let languageModel = DeepseekV3Model(config.textConfig)
        self._languageModel.wrappedValue = languageModel
        self._multiModalProjector.wrappedValue = KimiVLMultiModalProjector(config: config)

        let derivedKvHeads = (0 ..< config.textConfig.numHiddenLayers)
            .map { _ in config.textConfig.numKeyValueHeads }
        self.kvHeads = languageModel.kvHeads.isEmpty ? derivedKvHeads : languageModel.kvHeads
    }

    private func mergeInputEmbeddings(
        inputIds: MLXArray,
        inputEmbeds: MLXArray,
        imageFeatures: MLXArray
    ) -> MLXArray {
        let flatIds = inputIds.asArray(Int.self)
        var imageIndices: [Int] = []
        for (index, value) in flatIds.enumerated() where value == config.imageTokenIndex {
            imageIndices.append(index)
        }

        var result = inputEmbeds
        if result.ndim == 2 {
            result = result[.newAxis, 0..., 0...]
        }

        if !imageIndices.isEmpty {
            result[0..., MLXArray(imageIndices), 0...] = imageFeatures
        }

        return result
    }

    private func inputEmbeddings(
        inputIds: MLXArray,
        pixelValues: MLXArray?,
        gridHws: MLXArray?
    ) -> MLXArray {
        guard let pixelValues, let gridHws else {
            return languageModel.embedTokens(inputIds)
        }

        let inputEmbeds = languageModel.embedTokens(inputIds)
        let visionInput = pixelValues.transposed(0, 2, 3, 1)
        let visionHidden = visionTower(visionInput, gridHws: gridHws, outputHiddenStates: true)
        let projected = multiModalProjector(visionHidden)
        return mergeInputEmbeddings(
            inputIds: inputIds.squeezed(axis: 0),
            inputEmbeds: inputEmbeds,
            imageFeatures: projected
        )
    }

    func prepare(_ input: LMInput, cache: [KVCache], windowSize: Int?) throws -> PrepareResult {
        let dtype = visionTower.patchEmbed.proj.weight.dtype
        let pixelValues = input.image?.pixels.asType(dtype)

        var gridPairs: [Int] = []
        if let frames = input.image?.frames {
            for frame in frames {
                gridPairs.append(contentsOf: [frame.h, frame.w])
            }
        }
        let gridHws = gridPairs.isEmpty ? nil : MLXArray(gridPairs).reshaped(gridPairs.count / 2, 2)

        let inputEmbeds = inputEmbeddings(
            inputIds: input.text.tokens,
            pixelValues: pixelValues,
            gridHws: gridHws
        )

        let logits = languageModel.callAsFunction(
            nil,
            cache: cache,
            inputEmbedding: inputEmbeds
        )
        return .logits(.init(logits: logits))
    }

    func callAsFunction(_ inputs: MLXArray, cache: [KVCache]?) -> MLXArray {
        languageModel.callAsFunction(inputs, cache: cache)
    }

    func sanitize(weights: [String: MLXArray]) -> [String: MLXArray] {
        var remapped: [String: MLXArray] = [:]
        for (key, value) in weights {
            var newKey = key
            if newKey.contains("vision_tower") {
                newKey = newKey.replacingOccurrences(of: "encoder.", with: "")
            }
            if !newKey.contains("language_model") && !newKey.contains("vision_tower")
                && !newKey.contains("multi_modal_projector")
            {
                newKey = newKey.replacingOccurrences(of: "model", with: "language_model.model")
                newKey = newKey.replacingOccurrences(of: "lm_head", with: "language_model.lm_head")
            }
            remapped[newKey] = value
        }
        return visionTower.sanitize(weights: remapped)
    }

    func loraLinearLayers() -> LoRALinearLayers {
        languageModel.loraLinearLayers()
    }
}
