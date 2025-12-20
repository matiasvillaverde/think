import CoreML
import Foundation
import NaturalLanguage

@available(iOS 16.2, macOS 13.1, *)
public extension StableDiffusionPipeline {
    struct ResourceURLs {
        public let textEncoderURL: URL
        public let unetURL: URL
        public let unetChunk1URL: URL
        public let unetChunk2URL: URL
        public let decoderURL: URL
        public let encoderURL: URL
        public let safetyCheckerURL: URL
        public let vocabURL: URL
        public let mergesURL: URL
        public let controlNetDirURL: URL
        public let controlledUnetURL: URL
        public let controlledUnetChunk1URL: URL
        public let controlledUnetChunk2URL: URL
        public let multilingualTextEncoderProjectionURL: URL

        public init(resourcesAt baseURL: URL) {
            textEncoderURL = baseURL.appending(path: "TextEncoder.mlmodelc")
            unetURL = baseURL.appending(path: "Unet.mlmodelc")
            unetChunk1URL = baseURL.appending(path: "UnetChunk1.mlmodelc")
            unetChunk2URL = baseURL.appending(path: "UnetChunk2.mlmodelc")
            decoderURL = baseURL.appending(path: "VAEDecoder.mlmodelc")
            encoderURL = baseURL.appending(path: "VAEEncoder.mlmodelc")
            safetyCheckerURL = baseURL.appending(path: "SafetyChecker.mlmodelc")
            vocabURL = baseURL.appending(path: "vocab.json")
            mergesURL = baseURL.appending(path: "merges.txt")
            controlNetDirURL = baseURL.appending(path: "controlnet")
            controlledUnetURL = baseURL.appending(path: "ControlledUnet.mlmodelc")
            controlledUnetChunk1URL = baseURL.appending(path: "ControlledUnetChunk1.mlmodelc")
            controlledUnetChunk2URL = baseURL.appending(path: "ControlledUnetChunk2.mlmodelc")
            multilingualTextEncoderProjectionURL = baseURL.appending(path: "MultilingualTextEncoderProjection.mlmodelc")
        }
    }

    /// Create stable diffusion pipeline using model resources at a
    /// specified URL
    ///
    /// - Parameters:
    ///   - baseURL: URL pointing to directory holding all model and tokenization resources
    ///   - controlNetModelNames: Specify ControlNet models to use in generation
    ///   - configuration: The configuration to load model resources with
    ///   - disableSafety: Load time disable of safety to save memory
    ///   - reduceMemory: Setup pipeline in reduced memory mode
    ///   - useMultilingualTextEncoder: Option to use system multilingual NLContextualEmbedding as encoder
    ///   - script: Optional natural language script to use for the text encoder.
    /// - Returns:
    ///  Pipeline ready for image generation if all  necessary resources loaded
    init(
        resourcesAt baseURL: URL,
        controlNet controlNetModelNames: [String],
        configuration config: MLModelConfiguration = .init(),
        disableSafety: Bool = false,
        reduceMemory: Bool = false,
        useMultilingualTextEncoder: Bool = false,
        script: Script? = nil
    ) throws {
        let loadConfig = LoadConfiguration(
            urls: ResourceURLs(resourcesAt: baseURL),
            config: config,
            controlNetModelNames: controlNetModelNames,
            disableSafety: disableSafety,
            useMultilingualTextEncoder: useMultilingualTextEncoder,
            script: script
        )
        let components = try Self.loadPipelineComponents(loadConfig: loadConfig)

        self = Self.createPipeline(
            components: components,
            reduceMemory: reduceMemory,
            useMultilingualTextEncoder: useMultilingualTextEncoder,
            script: script
        )
    }

    /// Creates a pipeline with the loaded components
    private static func createPipeline(
        components: PipelineComponents,
        reduceMemory: Bool,
        useMultilingualTextEncoder: Bool,
        script: Script?
    ) -> StableDiffusionPipeline {
        if #available(macOS 14.0, iOS 17.0, *) {
            return StableDiffusionPipeline(
                textEncoder: components.textEncoder,
                unet: components.unet,
                decoder: components.decoder,
                encoder: components.encoder,
                controlNet: components.controlNet,
                safetyChecker: components.safetyChecker,
                reduceMemory: reduceMemory,
                useMultilingualTextEncoder: useMultilingualTextEncoder,
                script: script
            )
        } else {
            return StableDiffusionPipeline(
                textEncoder: components.textEncoder,
                unet: components.unet,
                decoder: components.decoder,
                encoder: components.encoder,
                controlNet: components.controlNet,
                safetyChecker: components.safetyChecker,
                reduceMemory: reduceMemory
            )
        }
    }

    /// Container for pipeline components
    private struct PipelineComponents {
        let textEncoder: TextEncoderModel
        let controlNet: ControlNet?
        let unet: Unet
        let decoder: Decoder
        let safetyChecker: SafetyChecker?
        let encoder: Encoder?
    }

    /// Configuration for loading pipeline components
    private struct LoadConfiguration {
        let urls: ResourceURLs
        let config: MLModelConfiguration
        let controlNetModelNames: [String]
        let disableSafety: Bool
        let useMultilingualTextEncoder: Bool
        let script: Script?
    }

    /// Loads all pipeline components
    private static func loadPipelineComponents(
        loadConfig: LoadConfiguration
    ) throws -> PipelineComponents {
        let textEncoder = try loadTextEncoder(
            urls: loadConfig.urls,
            config: loadConfig.config,
            useMultilingualTextEncoder: loadConfig.useMultilingualTextEncoder,
            script: loadConfig.script
        )

        let otherComponents = loadOtherComponents(loadConfig: loadConfig)

        return PipelineComponents(
            textEncoder: textEncoder,
            controlNet: otherComponents.controlNet,
            unet: otherComponents.unet,
            decoder: otherComponents.decoder,
            safetyChecker: otherComponents.safetyChecker,
            encoder: otherComponents.encoder
        )
    }

    /// Container for other pipeline components
    private struct OtherComponents {
        let controlNet: ControlNet?
        let unet: Unet
        let decoder: Decoder
        let safetyChecker: SafetyChecker?
        let encoder: Encoder?
    }

    /// Loads non-text-encoder components
    private static func loadOtherComponents(loadConfig: LoadConfiguration) -> OtherComponents {
        let controlNet = loadControlNet(
            controlNetModelNames: loadConfig.controlNetModelNames,
            urls: loadConfig.urls,
            config: loadConfig.config
        )

        let unet = loadUnet(
            urls: loadConfig.urls,
            config: loadConfig.config,
            hasControlNet: controlNet != nil
        )

        let decoder = Decoder(modelAt: loadConfig.urls.decoderURL, configuration: loadConfig.config)

        let safetyChecker = loadSafetyChecker(
            urls: loadConfig.urls,
            config: loadConfig.config,
            disableSafety: loadConfig.disableSafety
        )

        let encoder = loadEncoder(urls: loadConfig.urls, config: loadConfig.config)

        return OtherComponents(
            controlNet: controlNet,
            unet: unet,
            decoder: decoder,
            safetyChecker: safetyChecker,
            encoder: encoder
        )
    }

    /// Loads the text encoder based on configuration
    private static func loadTextEncoder(
        urls: ResourceURLs,
        config: MLModelConfiguration,
        useMultilingualTextEncoder: Bool,
        script: Script?
    ) throws -> TextEncoderModel {
#if canImport(NaturalLanguage.NLScript)
        if useMultilingualTextEncoder {
            guard #available(macOS 14.0, iOS 17.0, *) else {
                throw ImageGeneratorError.unsupportedOSVersion(
                    required: "macOS 14.0 / iOS 17.0",
                    current: ProcessInfo.processInfo.operatingSystemVersionString
                )
            }
            return MultilingualTextEncoder(
                modelAt: urls.multilingualTextEncoderProjectionURL,
                configuration: config,
                script: script ?? .latin
            )
        } else {
            let tokenizer = try BPETokenizer(mergesAt: urls.mergesURL, vocabularyAt: urls.vocabURL)
            return TextEncoder(tokenizer: tokenizer, modelAt: urls.textEncoderURL, configuration: config)
        }
#else
        let tokenizer = try BPETokenizer(mergesAt: urls.mergesURL, vocabularyAt: urls.vocabURL)
        return TextEncoder(tokenizer: tokenizer, modelAt: urls.textEncoderURL, configuration: config)
#endif
    }

    /// Loads the ControlNet model if specified
    private static func loadControlNet(
        controlNetModelNames: [String],
        urls: ResourceURLs,
        config: MLModelConfiguration
    ) -> ControlNet? {
        let controlNetURLs = controlNetModelNames.map { model in
            let fileName = model + ".mlmodelc"
            return urls.controlNetDirURL.appending(path: fileName)
        }
        return controlNetURLs.isEmpty ? nil : ControlNet(modelAt: controlNetURLs, configuration: config)
    }

    /// Loads the Unet model with appropriate configuration
    private static func loadUnet(
        urls: ResourceURLs,
        config: MLModelConfiguration,
        hasControlNet: Bool
    ) -> Unet {
        let unetURL: URL
        let unetChunk1URL: URL
        let unetChunk2URL: URL

        if hasControlNet {
            unetURL = urls.controlledUnetURL
            unetChunk1URL = urls.controlledUnetChunk1URL
            unetChunk2URL = urls.controlledUnetChunk2URL
        } else {
            unetURL = urls.unetURL
            unetChunk1URL = urls.unetChunk1URL
            unetChunk2URL = urls.unetChunk2URL
        }

        if FileManager.default.fileExists(atPath: unetChunk1URL.path),
            FileManager.default.fileExists(atPath: unetChunk2URL.path) {
            return Unet(chunksAt: [unetChunk1URL, unetChunk2URL], configuration: config)
        } else {
            return Unet(modelAt: unetURL, configuration: config)
        }
    }

    /// Loads the safety checker if enabled
    private static func loadSafetyChecker(
        urls: ResourceURLs,
        config: MLModelConfiguration,
        disableSafety: Bool
    ) -> SafetyChecker? {
        if !disableSafety, FileManager.default.fileExists(atPath: urls.safetyCheckerURL.path) {
            return SafetyChecker(modelAt: urls.safetyCheckerURL, configuration: config)
        }
        return nil
    }

    /// Loads the encoder if available
    private static func loadEncoder(urls: ResourceURLs, config: MLModelConfiguration) -> Encoder? {
        if FileManager.default.fileExists(atPath: urls.encoderURL.path) {
            return Encoder(modelAt: urls.encoderURL, configuration: config)
        }
        return nil
    }
}
