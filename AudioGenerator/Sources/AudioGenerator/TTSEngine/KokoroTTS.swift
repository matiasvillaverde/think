// swiftlint:disable force_unwrapping force_try shorthand_operator
import Foundation
import MLX
import MLXNN
import NaturalLanguage
import OSLog

// Available voices
public enum TTSVoice {
    case afHeart
    case bmGeorge
    case zfXiaoni
}

// Main class, encapsulates the whole Kokoro text-to-speech pipeline
public class KokoroTTS {
    // MARK: - Logging
    private static let logger: Logger = Logger(subsystem: "AudioGenerator", category: "KokoroTTS")

    enum KokoroTTSError: Error {
        case tooManyTokens
    }

    struct InputData {
        let paddedInputIds: MLXArray
        let attentionMask: MLXArray
        let inputIds: [Int]
        let inputLengths: MLXArray
        let textMask: MLXArray
    }

    private let bert: CustomAlbert!
    private let bertEncoder: Linear!
    private let durationEncoder: DurationEncoder!
    private let predictorLSTM: LSTM!
    private let durationProj: Linear!
    private let prosodyPredictor: ProsodyPredictor!
    private let textEncoder: TextEncoder!
    private let decoder: Decoder!
    private let eSpeakEngine: ESpeakNGEngine!
    private var chosenVoice: TTSVoice?
    private var voice: MLXArray!

    init() {
        Self.logger.info("Initializing KokoroTTS model components")
        let sanitizedWeights: [String: MLXArray] = WeightLoader.loadWeights()
        let config: KokoroConfig = KokoroConfig.loadConfig()

        bert = Self.createBert(weights: sanitizedWeights, config: config)
        bertEncoder = Linear(weight: sanitizedWeights["bert_encoder.weight"]!, bias: sanitizedWeights["bert_encoder.bias"]!)
        durationEncoder = DurationEncoder(weights: sanitizedWeights, dModel: config.hiddenDim, styDim: config.styleDim, nlayers: config.nLayer)
        predictorLSTM = Self.createPredictorLSTM(weights: sanitizedWeights, config: config)
        durationProj = Linear(
            weight: sanitizedWeights["predictor.duration_proj.linear_layer.weight"]!,
            bias: sanitizedWeights["predictor.duration_proj.linear_layer.bias"]!
        )
        prosodyPredictor = ProsodyPredictor(weights: sanitizedWeights, styleDim: config.styleDim, dHid: config.hiddenDim)
        textEncoder = Self.createTextEncoder(weights: sanitizedWeights, config: config)
        decoder = Self.createDecoder(weights: sanitizedWeights, config: config)
        eSpeakEngine = try! ESpeakNGEngine()
        Self.logger.notice("KokoroTTS initialization completed")
    }

    private static func createBert(weights: [String: MLXArray], config: KokoroConfig) -> CustomAlbert {
        CustomAlbert(
            weights: weights,
            config: AlbertModelArgs(
                numHiddenLayers: config.plbert.numHiddenLayers,
                numAttentionHeads: config.plbert.numAttentionHeads,
                hiddenSize: config.plbert.hiddenSize,
                intermediateSize: config.plbert.intermediateSize,
                vocabSize: config.nToken)
        )
    }

    private static func createPredictorLSTM(weights: [String: MLXArray], config: KokoroConfig) -> LSTM {
        LSTM(
            inputSize: config.hiddenDim + config.styleDim,
            hiddenSize: config.hiddenDim / 2,
            wxForward: weights["predictor.lstm.weight_ih_l0"]!,
            whForward: weights["predictor.lstm.weight_hh_l0"]!,
            biasIhForward: weights["predictor.lstm.bias_ih_l0"]!,
            biasHhForward: weights["predictor.lstm.bias_hh_l0"]!,
            wxBackward: weights["predictor.lstm.weight_ih_l0_reverse"]!,
            whBackward: weights["predictor.lstm.weight_hh_l0_reverse"]!,
            biasIhBackward: weights["predictor.lstm.bias_ih_l0_reverse"]!,
            biasHhBackward: weights["predictor.lstm.bias_hh_l0_reverse"]!
        )
    }

    private static func createTextEncoder(weights: [String: MLXArray], config: KokoroConfig) -> TextEncoder {
        TextEncoder(
            weights: weights,
            channels: config.hiddenDim,
            kernelSize: config.textEncoderKernelSize,
            depth: config.nLayer,
            nSymbols: config.nToken
        )
    }

    private static func createDecoder(weights: [String: MLXArray], config: KokoroConfig) -> Decoder {
        Decoder(
            weights: weights,
            dimIn: config.hiddenDim,
            styleDim: config.styleDim,
            dimOut: config.nMels,
            resblockKernelSizes: config.istftNet.resblockKernelSizes,
            upsampleRates: config.istftNet.upsampleRates,
            upsampleInitialChannel: config.istftNet.upsampleInitialChannel,
            resblockDilationSizes: config.istftNet.resblockDilationSizes,
            upsampleKernelSizes: config.istftNet.upsampleKernelSizes,
            genIstftNFft: config.istftNet.genIstftNFFT,
            genIstftHopSize: config.istftNet.genIstftHopSize
        )
    }

    /// Splits text into multiple chunks, ensuring each chunk doesn't exceed the maximum token count when phonemized.
    /// - Parameters:
    ///   - text: The text to split into chunks
    ///   - maxTokensPerChunk: Maximum number of tokens allowed per chunk (defaults to Constants.maxTokenCount)
    /// - Returns: An array of text chunks
    /// - Throws: Any errors from phonemization or tokenization processes
    func chunkTextByTokenLimit(text: String, maxTokensPerChunk: Int = Constants.maxTokenCount, voice: TTSVoice) throws -> [String] {
        if chosenVoice != voice {
            Self.logger.info("Switching to voice: \(String(describing: voice))")
            self.voice = VoiceLoader.loadVoice(voice)
            try eSpeakEngine.setLanguage(for: voice)
            chosenVoice = voice
        }

        // Step 1: Split text into sentences using Apple's NLTokenizer
        let tokenizer: NLTokenizer = NLTokenizer(unit: .sentence)
        tokenizer.string = text

        var sentences: [String] = []
        tokenizer.enumerateTokens(in: text.startIndex..<text.endIndex) { tokenRange, _ in
            let sentence: String = String(text[tokenRange])
            sentences.append(sentence)
            return true
        }

        // Step 2: Create chunks by testing token counts
        var chunks: [String] = []
        var currentText: String = ""

        for sentence in sentences {
            // Try adding this sentence to the current chunk
            let newText: String = currentText.isEmpty ? sentence : currentText + " " + sentence

            do {
                // Check if adding this sentence would exceed the token limit
                let phonemizedText: String = try eSpeakEngine.phonemize(text: newText)
                let tokens: [Int] = Tokenizer.tokenize(phonemizedText: phonemizedText)

                if tokens.count <= maxTokensPerChunk {
                    // We can safely add this sentence
                    currentText = newText
                } else {
                    // Adding this sentence would exceed the limit
                    // Save the current chunk if we have one
                    if !currentText.isEmpty {
                        chunks.append(currentText)
                    }

                    // Start a new chunk with just this sentence
                    // Check if this single sentence exceeds the limit
                    let phonemizedSentence: String = try eSpeakEngine.phonemize(text: sentence)
                    let sentenceTokens: [Int] = Tokenizer.tokenize(phonemizedText: phonemizedSentence)

                    if sentenceTokens.count > maxTokensPerChunk {
                        Self.logger.warning("Single sentence exceeds token limit (\(sentenceTokens.count) > \(maxTokensPerChunk))")
                    }

                    currentText = sentence
                }
            } catch {
                throw error
            }
        }

        // Add the final chunk if needed
        if !currentText.isEmpty {
            chunks.append(currentText)
        }

        return chunks
    }

    public func generateAudio(voice: TTSVoice, text: String, speed: Float = 1.0) throws -> MLXArray {
        Self.logger.info("Starting audio generation for \(text.count) characters")

        if chosenVoice != voice {
            Self.logger.info("Switching to voice: \(String(describing: voice))")
            self.voice = VoiceLoader.loadVoice(voice)
            try eSpeakEngine.setLanguage(for: voice)
            chosenVoice = voice
        }

        BenchmarkTimer.reset()
        BenchmarkTimer.startTimer(Constants.bmTTS)

        let inputData: InputData = try prepareInputData(text: text)
        let (dEn, refS, s): (MLXArray, MLXArray, MLXArray) = processTextThroughBert(
            paddedInputIds: inputData.paddedInputIds,
            attentionMask: inputData.attentionMask,
            inputIds: inputData.inputIds
        )
        let (en, predAlnTrg): (MLXArray, MLXArray) = processDurationPrediction(
            dEn: dEn,
            s: s,
            inputLengths: inputData.inputLengths,
            textMask: inputData.textMask,
            speed: speed,
            paddedInputIds: inputData.paddedInputIds
        )
        let audio: MLXArray = generateFinalAudio(
            en: en,
            s: s,
            paddedInputIds: inputData.paddedInputIds,
            inputLengths: inputData.inputLengths,
            textMask: inputData.textMask,
            predAlnTrg: predAlnTrg,
            refS: refS
        )

        BenchmarkTimer.stopTimer(Constants.bmTTS)
        BenchmarkTimer.print()

        Self.logger.notice("Audio generation completed successfully")
        return audio
    }

    enum Constants {
        static let maxTokenCount: Int = 510 // 510
        static let samplingRate: Int = 24_000

        static let bmTTS: String = "TTSAudio"
        static let bmPhonemize: String = "Phonemize"
        static let bmBert: String = "BERT"
        static let bmDuration: String = "Duration"
        static let bmProsody: String = "Prosody"
        static let bmDecoder: String = "Decoder"
    }

    deinit {
        // No explicit cleanup needed
    }

    // MARK: - Private Helper Methods

    private func prepareInputData(text: String) throws -> InputData {
        BenchmarkTimer.startTimer(Constants.bmPhonemize, Constants.bmTTS)

        let outputStr: String = try! eSpeakEngine.phonemize(text: text)
        let inputIds: [Int] = Tokenizer.tokenize(phonemizedText: outputStr)
        guard inputIds.count <= Constants.maxTokenCount else {
            Self.logger.error("Text exceeds token limit: \(inputIds.count) > \(Constants.maxTokenCount)")
            throw KokoroTTSError.tooManyTokens
        }

        let paddedInputIdsBase: [Int] = [0] + inputIds + [0]
        let paddedInputIds: MLXArray = MLXArray(paddedInputIdsBase).expandedDimensions(axes: [0])

        let inputLengths: MLXArray = MLXArray(paddedInputIds.dim(-1))
        let inputLengthMax: Int = inputLengths.max().item()
        var textMask: MLXArray = MLXArray(0 ..< inputLengthMax)
        textMask = textMask + 1 .> inputLengths
        textMask = textMask.expandedDimensions(axes: [0])
        let swiftTextMask: [Bool] = textMask.asArray(Bool.self)
        let swiftTextMaskInt: [Int] = swiftTextMask.map { !$0 ? 1 : 0 }
        let attentionMask: MLXArray = MLXArray(swiftTextMaskInt).reshaped(textMask.shape)

        BenchmarkTimer.stopTimer(Constants.bmPhonemize, [attentionMask, paddedInputIds])
        return InputData(
            paddedInputIds: paddedInputIds,
            attentionMask: attentionMask,
            inputIds: inputIds,
            inputLengths: inputLengths,
            textMask: textMask
        )
    }

    private func processTextThroughBert(paddedInputIds: MLXArray, attentionMask: MLXArray, inputIds: [Int]) -> (MLXArray, MLXArray, MLXArray) {
        BenchmarkTimer.startTimer(Constants.bmBert, Constants.bmTTS)
        let (bertDur, _): (MLXArray, MLXArray) = bert(paddedInputIds, attentionMask: attentionMask)
        let dEn: MLXArray = bertEncoder(bertDur).transposed(0, 2, 1)
        BenchmarkTimer.stopTimer(Constants.bmBert, [dEn])

        let refS: MLXArray = self.voice[inputIds.count - 1, 0 ... 1, 0...]
        let s: MLXArray = refS[0 ... 1, 128...]
        return (dEn, refS, s)
    }

    private func processDurationPrediction(
        dEn: MLXArray,
        s: MLXArray,
        inputLengths: MLXArray,
        textMask: MLXArray,
        speed: Float,
        paddedInputIds: MLXArray
    ) -> (MLXArray, MLXArray) {
        BenchmarkTimer.startTimer(Constants.bmDuration, Constants.bmTTS)
        let d: MLXArray = durationEncoder(dEn, style: s, textLengths: inputLengths, m: textMask)
        let (x, _): (MLXArray, ((MLXArray, MLXArray), (MLXArray, MLXArray))) = predictorLSTM(d)
        let duration: MLXArray = durationProj(x)
        let durationSigmoid: MLXArray = MLX.sigmoid(duration).sum(axis: -1) / speed
        let predDur: MLXArray = MLX.clip(durationSigmoid.round(), min: 1).asType(.int32)[0]

        let indices: MLXArray = MLX.concatenated(
            predDur.enumerated().map { i, n in
                let nSize: Int = n.item()
                return MLX.repeated(MLXArray([i]), count: nSize)
            }
        )

        var swiftPredAlnTrg: [Float] = [Float](repeating: 0.0, count: indices.shape[0] * paddedInputIds.shape[1])
        for i in 0 ..< indices.shape[0] {
            let indiceValue: Int = indices[i].item()
            swiftPredAlnTrg[indiceValue * indices.shape[0] + i] = 1.0
        }
        let predAlnTrg: MLXArray = MLXArray(swiftPredAlnTrg).reshaped([paddedInputIds.shape[1], indices.shape[0]])
        let predAlnTrgBatched: MLXArray = predAlnTrg.expandedDimensions(axis: 0)
        let en: MLXArray = d.transposed(0, 2, 1).matmul(predAlnTrgBatched)
        BenchmarkTimer.stopTimer(Constants.bmDuration, [en, s])

        return (en, predAlnTrg)
    }

    private func generateFinalAudio(
        en: MLXArray,
        s: MLXArray,
        paddedInputIds: MLXArray,
        inputLengths: MLXArray,
        textMask: MLXArray,
        predAlnTrg: MLXArray,
        refS: MLXArray
    ) -> MLXArray {
        BenchmarkTimer.startTimer(Constants.bmProsody, Constants.bmTTS)
        let (f0Prediction, noisePrediction): (MLXArray, MLXArray) = prosodyPredictor.F0NTrain(x: en, s: s)
        let tEn: MLXArray = textEncoder(paddedInputIds, inputLengths: inputLengths, m: textMask)
        let asr: MLXArray = MLX.matmul(tEn, predAlnTrg)
        BenchmarkTimer.stopTimer(Constants.bmProsody, [asr, f0Prediction, noisePrediction])

        BenchmarkTimer.startTimer(Constants.bmDecoder, Constants.bmTTS)
        let audio: MLXArray = decoder(asr: asr, F0Curve: f0Prediction, N: noisePrediction, s: refS[0 ... 1, 0 ... 127])[0]
        BenchmarkTimer.stopTimer(Constants.bmDecoder, [audio])

        return audio
    }
}
// swiftlint:enable force_unwrapping force_try shorthand_operator
