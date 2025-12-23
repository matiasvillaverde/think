import Foundation
import Hub
import MLX
import Tokenizers

internal struct BaseProcessorConfiguration: Codable, Sendable {
    let processorClass: String

    enum CodingKeys: String, CodingKey {
        case processorClass = "processor_class"
    }
}

private func create<C: Decodable & Sendable, M: LanguageModel>(
    _ configurationType: C.Type,
    _ modelInit: @escaping @Sendable (C) -> M
    ) -> @Sendable (URL) throws -> any LanguageModel {
    { url in
        let data = try loadJSONData(from: url)
        let configuration = try JSONDecoder().decode(C.self, from: data)
        return modelInit(configuration)
    }
}

private func create<C: Decodable & Sendable, P>(
    _ configurationType: C.Type,
    _ processorInit: @escaping (C, any Tokenizer) -> P
) -> (Data, any Tokenizer) throws -> P {
    { data, tokenizer in
        let configuration = try JSONDecoder().decode(C.self, from: data)
        return processorInit(configuration, tokenizer)
    }
}

internal enum VLMTypeRegistry {
    static let shared: ModelTypeRegistry = .init(
        creators: [
            "kimi_vl": create(KimiVLConfiguration.self, KimiVLModel.init),
            "gemma3": create(Gemma3VLMConfiguration.self, Gemma3VLMModel.init),
            "qwen3_vl": create(Qwen3VLConfiguration.self, Qwen3VL.init)
        ] as [String: @Sendable (URL) throws -> any LanguageModel]
    )
}

internal enum VLMProcessorTypeRegistry {
    static let shared: ProcessorTypeRegistry = .init(creators: [
        "KimiVLProcessor": create(KimiVLProcessorConfiguration.self, KimiVLProcessor.init),
        "Gemma3Processor": create(Gemma3VLMProcessorConfiguration.self, Gemma3VLMProcessor.init),
        "Qwen3VLProcessor": create(Qwen3VLProcessorConfiguration.self, Qwen3VLProcessor.init)
    ])
}

internal final class VLMRegistry: AbstractModelRegistry, @unchecked Sendable {
    static let shared = VLMRegistry(modelConfigurations: all())

    static let kimiVLA3BThinking4bit = ModelConfiguration(
        id: "mlx-community/Kimi-VL-A3B-Thinking-4bit",
        defaultPrompt: "Describe the image in English"
    )
    static let gemma3Vlm4bItQat3bit = ModelConfiguration(
        id: "mlx-community/gemma-3-4b-it-qat-3bit",
        defaultPrompt: "Describe the image in English"
    )
    static let qwen3Vlm4bInstruct3bit = ModelConfiguration(
        id: "mlx-community/Qwen3-VL-4B-Instruct-3bit",
        defaultPrompt: "Describe the image in English"
    )

    static func all() -> [ModelConfiguration] {
        [
            kimiVLA3BThinking4bit,
            gemma3Vlm4bItQat3bit,
            qwen3Vlm4bInstruct3bit
        ]
    }
}

internal final class VLMModelFactory: ModelFactory {
    internal init(
        typeRegistry: ModelTypeRegistry,
        processorRegistry: ProcessorTypeRegistry,
        modelRegistry: AbstractModelRegistry
    ) {
        self.typeRegistry = typeRegistry
        self.processorRegistry = processorRegistry
        self.modelRegistry = modelRegistry
    }

    internal static let shared = VLMModelFactory(
        typeRegistry: VLMTypeRegistry.shared,
        processorRegistry: VLMProcessorTypeRegistry.shared,
        modelRegistry: VLMRegistry.shared
    )

    internal let typeRegistry: ModelTypeRegistry
    internal let processorRegistry: ProcessorTypeRegistry
    internal let modelRegistry: AbstractModelRegistry

    internal func _load(
        hub: HubApi,
        configuration: ModelConfiguration,
        progressHandler: @Sendable @escaping (Progress) -> Void
    ) async throws -> sending ModelContext {
        let modelDirectory = try await downloadModel(
            hub: hub,
            configuration: configuration,
            progressHandler: progressHandler
        )

        let configurationURL = modelDirectory.appending(component: "config.json")
        let configData: Data
        do {
            configData = try loadJSONData(from: configurationURL)
        } catch {
            throw ModelFactoryError.configurationFileError(
                configurationURL.lastPathComponent,
                configuration.name,
                error
            )
        }

        let baseConfig: BaseConfiguration
        do {
            baseConfig = try JSONDecoder().decode(BaseConfiguration.self, from: configData)
        } catch let error as DecodingError {
            throw ModelFactoryError.configurationDecodingError(
                configurationURL.lastPathComponent,
                configuration.name,
                error
            )
        }

        let model: LanguageModel
        do {
            model = try typeRegistry.createModel(
                configuration: configurationURL,
                modelType: baseConfig.modelType
            )
        } catch let error as DecodingError {
            throw ModelFactoryError.configurationDecodingError(
                configurationURL.lastPathComponent,
                configuration.name,
                error
            )
        }

        async let tokenizerTask = loadTokenizer(configuration: configuration, hub: hub)
        async let processorConfigTask = loadProcessorConfig(from: modelDirectory)

        try loadWeights(
            modelDirectory: modelDirectory,
            model: model,
            perLayerQuantization: baseConfig.perLayerQuantization
        )

        let tokenizer = try await tokenizerTask
        let processorConfigData: Data
        let baseProcessorConfig: BaseProcessorConfiguration
        do {
            (processorConfigData, baseProcessorConfig) = try await processorConfigTask
        } catch let error as ProcessorConfigError {
            if let decodingError = error.underlying as? DecodingError {
                throw ModelFactoryError.configurationDecodingError(
                    error.filename,
                    configuration.name,
                    decodingError
                )
            }
            throw ModelFactoryError.configurationFileError(
                error.filename,
                configuration.name,
                error.underlying
            )
        }

        let processor = try await processorRegistry.createModel(
            configuration: processorConfigData,
            processorType: baseProcessorConfig.processorClass,
            tokenizer: tokenizer
        )

        return ModelContext(
            configuration: configuration,
            model: model,
            processor: processor,
            tokenizer: tokenizer
        )
    }
}

private struct ProcessorConfigError: Error {
    let filename: String
    let underlying: Error
}

private func loadProcessorConfig(from modelDirectory: URL) async throws -> (Data, BaseProcessorConfiguration) {
    let processorConfigURL = modelDirectory.appending(component: "processor_config.json")
    let preprocessorConfigURL = modelDirectory.appending(component: "preprocessor_config.json")
    let url =
        FileManager.default.fileExists(atPath: preprocessorConfigURL.path)
        ? preprocessorConfigURL
        : processorConfigURL
    do {
        let data = try Data(contentsOf: url)
        let config = try JSONDecoder().decode(BaseProcessorConfiguration.self, from: data)
        return (data, config)
    } catch {
        throw ProcessorConfigError(filename: url.lastPathComponent, underlying: error)
    }
}
