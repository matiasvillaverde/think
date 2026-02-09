import Abstractions
import Foundation
@testable import ModelDownloader
import Testing

// MARK: - Configuration Tests

@Test("LanguageModelConfiguration should parse config.json correctly")
internal func testConfigurationParsing() throws {
    let configJSON: String = """
    {
        "model_type": "llama",
        "architectures": ["LlamaForCausalLM"],
        "vocab_size": 32000,
        "hidden_size": 4096,
        "intermediate_size": 11008,
        "num_hidden_layers": 32,
        "num_attention_heads": 32,
        "num_key_value_heads": 32,
        "rms_norm_eps": 1e-06,
        "max_position_embeddings": 2048,
        "rope_scaling": null,
        "rope_theta": 10000.0,
        "bos_token_id": 1,
        "eos_token_id": 2,
        "pad_token_id": 0,
        "tie_word_embeddings": false,
        "torch_dtype": "float16"
    }
    """

    let data: Data = Data(configJSON.utf8)
    let config: LanguageModelConfiguration = try JSONDecoder().decode(LanguageModelConfiguration.self, from: data)

    #expect(config.modelType == "llama")
    #expect(config.architectures?.first == "LlamaForCausalLM")
    #expect(config.vocabSize == 32_000)
    #expect(config.hiddenSize == 4_096)
    #expect(config.numHiddenLayers == 32)
    #expect(config.numAttentionHeads == 32)
    #expect(config.maxPositionEmbeddings == 2_048)
    #expect(config.torchDtype == "float16")
}

@Test("LanguageModelConfiguration should handle missing fields")
internal func testConfigurationWithMissingFields() throws {
    let minimalJSON: String = """
    {
        "model_type": "gpt2",
        "vocab_size": 50257,
        "hidden_size": 768,
        "num_hidden_layers": 12,
        "num_attention_heads": 12
    }
    """

    let data: Data = Data(minimalJSON.utf8)
    let config: LanguageModelConfiguration = try JSONDecoder().decode(LanguageModelConfiguration.self, from: data)

    #expect(config.modelType == "gpt2")
    #expect(config.vocabSize == 50_257)
    #expect(config.architectures == nil)
    #expect(config.intermediateSize == nil)
    #expect(config.maxPositionEmbeddings == nil)
}

@Test("LanguageModelConfigurationFromHub should load configuration from repository")
internal func testLoadConfigurationFromHub() async throws {
    let mockHTTPClient: ConfigurableMockHTTPClient = ConfigurableMockHTTPClient()
    let mockTokenManager: HFTokenManager = HFTokenManager(httpClient: mockHTTPClient)
    let hubAPI: HubAPI = HubAPI(
        endpoint: "https://huggingface.co",
        httpClient: mockHTTPClient,
        tokenManager: mockTokenManager
    )

    let configLoader: LanguageModelConfigurationFromHub = LanguageModelConfigurationFromHub(
        hubAPI: hubAPI,
        tokenManager: mockTokenManager
    )

    // Mock config.json response
    let configJSON: String = """
    {
        "model_type": "llama",
        "architectures": ["LlamaForCausalLM"],
        "vocab_size": 32000,
        "hidden_size": 4096,
        "num_hidden_layers": 32,
        "num_attention_heads": 32,
        "torch_dtype": "float16"
    }
    """

    mockHTTPClient.mockResponses[
        "https://huggingface.co/meta-llama/Llama-2-7b-hf/resolve/main/config.json"
    ] = HTTPClientResponse(
        data: Data(configJSON.utf8),
        statusCode: 200,
        headers: [:]
    )

    let config: LanguageModelConfiguration = try await configLoader.loadConfiguration(
        modelId: "meta-llama/Llama-2-7b-hf",
        revision: "main"
    )

    #expect(config.modelType == "llama")
    #expect(config.vocabSize == 32_000)
    #expect(config.hiddenSize == 4_096)
}

@Test("LanguageModelConfigurationFromHub should handle missing config.json")
internal func testMissingConfiguration() async {
    let mockHTTPClient: ConfigurableMockHTTPClient = ConfigurableMockHTTPClient()
    let mockTokenManager: HFTokenManager = HFTokenManager(httpClient: mockHTTPClient)
    let hubAPI: HubAPI = HubAPI(
        endpoint: "https://huggingface.co",
        httpClient: mockHTTPClient,
        tokenManager: mockTokenManager
    )

    let configLoader: LanguageModelConfigurationFromHub = LanguageModelConfigurationFromHub(
        hubAPI: hubAPI,
        tokenManager: mockTokenManager
    )

    // Mock 404 response
    mockHTTPClient.mockResponses["https://huggingface.co/test/model/resolve/main/config.json"] = HTTPClientResponse(
        data: Data(),
        statusCode: 404,
        headers: [:]
    )

    do {
        _ = try await configLoader.loadConfiguration(
            modelId: "test/model",
            revision: "main"
        )
        #expect(Bool(false), "Should have thrown an error")
    } catch {
        #expect(error is HuggingFaceError)
    }
}

@Test("ModelValidator should validate model compatibility")
internal func testModelValidation() async throws {
    let validator: ModelValidator = ModelValidator()

    // Valid Llama model
    let llamaConfig: LanguageModelConfiguration = LanguageModelConfiguration(
        modelType: "llama",
        architectures: ["LlamaForCausalLM"],
        vocabSize: 32_000,
        hiddenSize: 4_096,
        intermediateSize: 11_008,
        numHiddenLayers: 32,
        numAttentionHeads: 32,
        numKeyValueHeads: 32,
        rmsNormEps: 1e-06,
        maxPositionEmbeddings: 2_048,
        ropeScaling: nil,
        ropeTheta: 10_000.0,
        bosTokenId: 1,
        eosTokenId: 2,
        padTokenId: 0,
        tieWordEmbeddings: false,
        torchDtype: "float16"
    )

    let llamaValidation: ModelValidationResult = try await validator.validateModel(
        configuration: llamaConfig,
        backend: SendableModel.Backend.gguf
    )

    #expect(llamaValidation.isCompatible)
    #expect(llamaValidation.warnings.isEmpty)

    // Unsupported model type
    let unsupportedConfig: LanguageModelConfiguration = LanguageModelConfiguration(
        modelType: "custom_model",
        architectures: ["CustomModel"],
        vocabSize: 10_000,
        hiddenSize: 512,
        intermediateSize: nil,
        numHiddenLayers: 6,
        numAttentionHeads: 8,
        numKeyValueHeads: nil,
        rmsNormEps: nil,
        maxPositionEmbeddings: nil,
        ropeScaling: nil,
        ropeTheta: nil,
        bosTokenId: nil,
        eosTokenId: nil,
        padTokenId: nil,
        tieWordEmbeddings: nil,
        torchDtype: nil
    )

    let unsupportedValidation: ModelValidationResult = try await validator.validateModel(
        configuration: unsupportedConfig,
        backend: SendableModel.Backend.mlx
    )

    #expect(!unsupportedValidation.isCompatible)
    #expect(!unsupportedValidation.errors.isEmpty)
}

@Test("ModelValidator should check format compatibility")
internal func testFormatCompatibility() async throws {
    let validator: ModelValidator = ModelValidator()

    let config: LanguageModelConfiguration = LanguageModelConfiguration(
        modelType: "gpt2",
        architectures: ["GPT2LMHeadModel"],
        vocabSize: 50_257,
        hiddenSize: 768,
        intermediateSize: nil,
        numHiddenLayers: 12,
        numAttentionHeads: 12,
        numKeyValueHeads: nil,
        rmsNormEps: nil,
        maxPositionEmbeddings: 1_024,
        ropeScaling: nil,
        ropeTheta: nil,
        bosTokenId: nil,
        eosTokenId: 50_256,
        padTokenId: nil,
        tieWordEmbeddings: nil,
        torchDtype: "float32"
    )

    // Check different formats
    let mlxValidation: ModelValidationResult = try await validator.validateModel(
        configuration: config,
        backend: SendableModel.Backend.mlx
    )
    #expect(mlxValidation.isCompatible)

    let ggufValidation: ModelValidationResult = try await validator.validateModel(
        configuration: config,
        backend: SendableModel.Backend.gguf
    )
    #expect(ggufValidation.isCompatible)

    let coremlValidation: ModelValidationResult = try await validator.validateModel(
        configuration: config,
        backend: SendableModel.Backend.coreml
    )
    #expect(coremlValidation.isCompatible)
}

@Test("ModelValidator should treat unknown architectures as warnings for GGUF")
internal func testUnknownArchitectureIsWarningForGGUF() async throws {
    let validator: ModelValidator = ModelValidator()

    let config: LanguageModelConfiguration = LanguageModelConfiguration(
        modelType: "llama",
        architectures: ["TotallyUnknownForCausalLM"],
        vocabSize: 32_000,
        hiddenSize: 4_096,
        intermediateSize: 11_008,
        numHiddenLayers: 32,
        numAttentionHeads: 32,
        numKeyValueHeads: 32,
        rmsNormEps: 1e-06,
        maxPositionEmbeddings: 2_048,
        ropeScaling: nil,
        ropeTheta: 10_000.0,
        bosTokenId: 1,
        eosTokenId: 2,
        padTokenId: 0,
        tieWordEmbeddings: false,
        torchDtype: "float16"
    )

    let ggufValidation: ModelValidationResult = try await validator.validateModel(
        configuration: config,
        backend: SendableModel.Backend.gguf
    )

    #expect(ggufValidation.isCompatible)
    #expect(ggufValidation.errors.isEmpty)
    #expect(!ggufValidation.warnings.isEmpty)

    let mlxValidation: ModelValidationResult = try await validator.validateModel(
        configuration: config,
        backend: SendableModel.Backend.mlx
    )
    #expect(!mlxValidation.isCompatible)
    #expect(!mlxValidation.errors.isEmpty)
}

@Test("ModelMetadataExtractor should extract model information")
internal func testMetadataExtraction() async throws {
    let extractor: ModelMetadataExtractor = ModelMetadataExtractor()

    let config: LanguageModelConfiguration = LanguageModelConfiguration(
        modelType: "llama",
        architectures: ["LlamaForCausalLM"],
        vocabSize: 32_000,
        hiddenSize: 4_096,
        intermediateSize: 11_008,
        numHiddenLayers: 32,
        numAttentionHeads: 32,
        numKeyValueHeads: 32,
        rmsNormEps: 1e-06,
        maxPositionEmbeddings: 2_048,
        ropeScaling: nil,
        ropeTheta: 10_000.0,
        bosTokenId: 1,
        eosTokenId: 2,
        padTokenId: 0,
        tieWordEmbeddings: false,
        torchDtype: "float16"
    )

    let files: [FileInfo] = [
        FileInfo(path: "model-00001-of-00003.safetensors", size: 5_000_000_000, lfs: nil),
        FileInfo(path: "model-00002-of-00003.safetensors", size: 5_000_000_000, lfs: nil),
        FileInfo(path: "model-00003-of-00003.safetensors", size: 3_000_000_000, lfs: nil),
        FileInfo(path: "config.json", size: 1_024, lfs: nil),
        FileInfo(path: "tokenizer.json", size: 2_048, lfs: nil)
    ]

    let extractedMetadata: Any = try await extractor.extractMetadata(
        configuration: config,
        files: files,
        modelId: "meta-llama/Llama-2-7b-hf"
    )

    // Use Mirror to access properties
    let mirror: Mirror = Mirror(reflecting: extractedMetadata)
    let modelType: String? = mirror.children.first { $0.label == "modelType" }?.value as? String
    let architecture: String? = mirror.children.first { $0.label == "architecture" }?.value as? String
    let parameters: String? = mirror.children.first { $0.label == "parameters" }?.value as? String
    let totalSize: Int64? = mirror.children.first { $0.label == "totalSize" }?.value as? Int64

    #expect(modelType == "llama")
    #expect(architecture == "LlamaForCausalLM")
    #expect(parameters == "7B")
    #expect(totalSize == 13_000_003_072)

    let quantization: String?? = mirror.children.first { $0.label == "quantization" }?.value as? String?
    let contextLength: Int?? = mirror.children.first { $0.label == "contextLength" }?.value as? Int?
    #expect(quantization == nil)
    #expect(contextLength == 2_048)
}
