// Copyright © 2024 Apple Inc.

import MLX

import Tokenizers

/// Marker protocol for LLMModels
internal protocol LLMModel: LanguageModel, LoRAModel {
}

extension LLMModel {
    /// Default prepare step for ``LLMModel``.
    ///
    /// This will evaluate the prompt in chunks until there is a small amount of
    /// tokens left to feed into the `TokenIterator`.
    internal func prepare(_ input: LMInput, cache: [KVCache], windowSize: Int?) throws
        -> PrepareResult {
        let prefillStepSize = windowSize ?? GenerationConstants.defaultPrefillStepSize
        var y = input.text
        var state: LMOutput.State?

        // prepare the prompt in chunks if larger than the prefill size
        while y.tokens.size > prefillStepSize {
            let input = y[.newAxis, ..<prefillStepSize]
            let result = self(input, cache: cache.isEmpty ? nil : cache, state: state)
            eval(cache)
            y = y[prefillStepSize...]
        }

        return .tokens(y)
    }
}
