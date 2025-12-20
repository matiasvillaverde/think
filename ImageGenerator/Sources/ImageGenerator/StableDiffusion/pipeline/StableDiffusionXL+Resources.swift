import CoreML
import Foundation
import NaturalLanguage

@available(iOS 17.0, macOS 14.0, *)
public extension StableDiffusionXLPipeline {
    struct ResourceURLs {
        public let textEncoderURL: URL
        public let textEncoder2URL: URL
        public let unetURL: URL
        public let unetChunk1URL: URL
        public let unetChunk2URL: URL
        public let unetRefinerURL: URL
        public let unetRefinerChunk1URL: URL
        public let unetRefinerChunk2URL: URL
        public let decoderURL: URL
        public let encoderURL: URL
        public let vocabURL: URL
        public let mergesURL: URL

        public init(resourcesAt baseURL: URL) {
            textEncoderURL = baseURL.appending(path: "TextEncoder.mlmodelc")
            textEncoder2URL = baseURL.appending(path: "TextEncoder2.mlmodelc")
            unetURL = baseURL.appending(path: "Unet.mlmodelc")
            unetChunk1URL = baseURL.appending(path: "UnetChunk1.mlmodelc")
            unetChunk2URL = baseURL.appending(path: "UnetChunk2.mlmodelc")
            unetRefinerURL = baseURL.appending(path: "UnetRefiner.mlmodelc")
            unetRefinerChunk1URL = baseURL.appending(path: "UnetRefinerChunk1.mlmodelc")
            unetRefinerChunk2URL = baseURL.appending(path: "UnetRefinerChunk2.mlmodelc")
            decoderURL = baseURL.appending(path: "VAEDecoder.mlmodelc")
            encoderURL = baseURL.appending(path: "VAEEncoder.mlmodelc")
            vocabURL = baseURL.appending(path: "vocab.json")
            mergesURL = baseURL.appending(path: "merges.txt")
        }
    }

    /// Create stable diffusion pipeline using model resources at a
    /// specified URL
    ///
    /// - Parameters:
    ///   - baseURL: URL pointing to directory holding all model and tokenization resources
    ///   - configuration: The configuration to load model resources with
    ///   - reduceMemory: Setup pipeline in reduced memory mode
    /// - Returns:
    ///  Pipeline ready for image generation if all  necessary resources loaded
    init(
        resourcesAt baseURL: URL,
        configuration config: MLModelConfiguration = .init(),
        reduceMemory: Bool = false
    ) throws {
        let urls = ResourceURLs(resourcesAt: baseURL)
        let (textEncoder, textEncoder2) = try Self.loadTextEncoders(urls: urls, config: config)
        let (unet, unetRefiner) = Self.loadUnetModels(urls: urls, config: config)
        let (decoder, encoder) = Self.loadVAEModels(urls: urls, config: config)

        self.init(
            textEncoder: textEncoder,
            textEncoder2: textEncoder2,
            unet: unet,
            unetRefiner: unetRefiner,
            decoder: decoder,
            encoder: encoder,
            reduceMemory: reduceMemory
        )
    }

    /// Loads text encoders for SDXL
    private static func loadTextEncoders(
        urls: ResourceURLs,
        config: MLModelConfiguration
    ) throws -> (textEncoder: TextEncoderXL?, textEncoder2: TextEncoderXL) {
        let tokenizer = try BPETokenizer(mergesAt: urls.mergesURL, vocabularyAt: urls.vocabURL)
        let textEncoder: TextEncoderXL?
        if FileManager.default.fileExists(atPath: urls.textEncoderURL.path) {
            textEncoder = TextEncoderXL(tokenizer: tokenizer, modelAt: urls.textEncoderURL, configuration: config)
        } else {
            textEncoder = nil
        }

        // padToken is different in the second XL text encoder
        let tokenizer2 = try BPETokenizer(mergesAt: urls.mergesURL, vocabularyAt: urls.vocabURL, padToken: "!")
        let textEncoder2 = TextEncoderXL(tokenizer: tokenizer2, modelAt: urls.textEncoder2URL, configuration: config)

        return (textEncoder, textEncoder2)
    }

    /// Loads Unet models including optional refiner
    private static func loadUnetModels(
        urls: ResourceURLs,
        config: MLModelConfiguration
    ) -> (unet: Unet, unetRefiner: Unet?) {
        let unet: Unet
        if FileManager.default.fileExists(atPath: urls.unetChunk1URL.path),
            FileManager.default.fileExists(atPath: urls.unetChunk2URL.path) {
            unet = Unet(chunksAt: [urls.unetChunk1URL, urls.unetChunk2URL], configuration: config)
        } else {
            unet = Unet(modelAt: urls.unetURL, configuration: config)
        }

        let unetRefiner: Unet?
        if FileManager.default.fileExists(atPath: urls.unetRefinerChunk1URL.path),
            FileManager.default.fileExists(atPath: urls.unetRefinerChunk2URL.path) {
            unetRefiner = Unet(chunksAt: [urls.unetRefinerChunk1URL, urls.unetRefinerChunk2URL], configuration: config)
        } else if FileManager.default.fileExists(atPath: urls.unetRefinerURL.path) {
            unetRefiner = Unet(modelAt: urls.unetRefinerURL, configuration: config)
        } else {
            unetRefiner = nil
        }

        return (unet, unetRefiner)
    }

    /// Loads VAE decoder and optional encoder
    private static func loadVAEModels(
        urls: ResourceURLs,
        config: MLModelConfiguration
    ) -> (decoder: Decoder, encoder: Encoder?) {
        // Hardcoding to .cpuAndGPU since ANE doesn't support FLOAT32
        guard let vaeConfig = config.copy() as? MLModelConfiguration else {
            fatalError("Failed to copy MLModelConfiguration")
        }
        vaeConfig.computeUnits = .cpuAndGPU

        let decoder = Decoder(modelAt: urls.decoderURL, configuration: vaeConfig)

        let encoder: Encoder?
        if FileManager.default.fileExists(atPath: urls.encoderURL.path) {
            encoder = Encoder(modelAt: urls.encoderURL, configuration: vaeConfig)
        } else {
            encoder = nil
        }

        return (decoder, encoder)
    }
}
