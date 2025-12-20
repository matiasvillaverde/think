import Abstractions
import Foundation
@testable import MLXSession
import Testing

/// Base class for model testing with common utilities
public struct BaseModelTest {
    private static let requiredFiles: [String] = ["config.json", "tokenizer.json"]
    private static let weightFiles: [String] = ["model.safetensors", "model.safetensors.index.json"]

    /// Initializes a new BaseModelTest instance
    public init() {
        // Initialization for BaseModelTest
    }

    /// Verifies that required model files exist at the specified path
    /// - Parameter modelPath: The path to the model directory
    /// - Throws: Assertion failures if required files are missing
    public func verifyModelFiles(at modelPath: String) throws {
        let requiredFiles = Self.requiredFiles

        var foundRequired = 0
        for file in requiredFiles {
            let filePath = modelPath + "/" + file
            if FileManager.default.fileExists(atPath: filePath) {
                foundRequired += 1
            }
        }

        #expect(
            foundRequired == requiredFiles.count,
            "Required model files missing at \(modelPath). Found \(foundRequired)/\(requiredFiles.count)"
        )

        // Check for at least one model file (safetensors or index)
        let modelFile = modelPath + "/" + Self.weightFiles[0]
        let modelIndex = modelPath + "/" + Self.weightFiles[1]

        #expect(
            FileManager.default.fileExists(atPath: modelFile) ||
            FileManager.default.fileExists(atPath: modelIndex),
            "No model weights found (neither model.safetensors nor model.safetensors.index.json)"
        )
    }

    /// Result of processing a stream of LLM chunks
    public struct StreamResult {
        /// The generated text from the stream
        public let text: String
        /// Whether any text was received
        public let hasReceivedText: Bool
        /// Optional metrics from the stream
        public let metrics: ChunkMetrics?
    }

    /// Processes an async stream of LLM chunks
    /// - Parameter stream: The async throwing stream of LLM chunks
    /// - Returns: A StreamResult containing the processed text and metrics
    /// - Throws: Any errors from the stream processing
    public func processStream(
        _ stream: AsyncThrowingStream<LLMStreamChunk, Error>
    ) async throws -> StreamResult {
        var generatedText = ""
        var hasReceivedText = false
        var finalMetrics: ChunkMetrics?

        for try await chunk in stream {
            switch chunk.event {
            case .text:
                generatedText += chunk.text
                hasReceivedText = true

            case .finished:
                finalMetrics = chunk.metrics

            default:
                break
            }
        }

        return StreamResult(
            text: generatedText,
            hasReceivedText: hasReceivedText,
            metrics: finalMetrics
        )
    }

    /// Verifies that metrics from generation are valid
    /// - Parameter metrics: Optional chunk metrics to verify
    public func verifyMetrics(_ metrics: ChunkMetrics?) {
        #expect(metrics != nil, "Should receive metrics with finished event")
        if let metrics {
            #expect(metrics.timing?.totalTime ?? .zero > .zero, "Total time should be positive")
            #expect(metrics.usage?.generatedTokens ?? 0 > 0, "Should have generated tokens")
            #expect(metrics.generation?.stopReason != nil, "Should report stop reason")
        }
    }

    /// Gets the URL for a model resource in a bundle
    /// - Parameters:
    ///   - resourceName: Name of the resource
    ///   - bundle: Bundle containing the resource
    /// - Returns: URL to the model resource
    /// - Throws: LLMError if resource not found
    public func getModelURL(resourceName: String, in bundle: Bundle) throws -> URL {
        guard let modelPath = bundle.path(
            forResource: resourceName,
            ofType: nil,
            inDirectory: "Resources"
        ) else {
            throw LLMError.modelNotFound("\(resourceName) not found in bundle")
        }
        return URL(fileURLWithPath: modelPath)
    }

    /// Gets the URL for a model resource if required files are available
    /// - Parameters:
    ///   - resourceName: Name of the resource
    ///   - bundle: Bundle containing the resource
    /// - Returns: URL to the model resource or nil if files are missing
    public func getModelURLIfAvailable(resourceName: String, in bundle: Bundle) -> URL? {
        guard let modelPath = bundle.path(
            forResource: resourceName,
            ofType: nil,
            inDirectory: "Resources"
        ) else {
            return nil
        }

        guard isModelAvailable(at: modelPath) else {
            return nil
        }

        return URL(fileURLWithPath: modelPath)
    }

    /// Runs a basic generation test with a model
    /// - Parameters:
    ///   - modelURL: URL to the model
    ///   - modelName: Name of the model
    ///   - prompt: Input prompt for generation
    ///   - expectedTokens: Expected tokens in output
    ///   - maxTokens: Maximum tokens to generate
    /// - Throws: Errors from model loading or generation
    public func runBasicGenerationTest(
        modelURL: URL,
        modelName: String,
        prompt: String = "The capital of France is",
        expectedTokens: [String] = ["paris"],
        maxTokens: Int = 5
    ) async throws {
        try verifyModelFiles(at: modelURL.path)

        let config = createConfig(modelURL: modelURL, modelName: modelName)
        let session = MLXSessionFactory.create()

        let preloadStream = await session.preload(configuration: config)
        for try await _ in preloadStream {
            // Consume progress updates
        }

        let input = createInput(prompt: prompt, maxTokens: maxTokens)
        let stream = await session.stream(input)
        let result = try await processStream(stream)

        validateResult(result, expectedTokens: expectedTokens)
        verifyMetrics(result.metrics)
        await session.unload()
    }

    /// Runs generation test and returns the text for string assertions
    /// - Parameters:
    ///   - modelURL: URL to the model
    ///   - modelName: Name of the model
    ///   - prompt: Input prompt for generation
    ///   - maxTokens: Maximum tokens to generate
    /// - Returns: Generated text string
    /// - Throws: Errors from model loading or generation
    public func runGenerationForAssertion(
        modelURL: URL,
        modelName: String,
        prompt: String,
        maxTokens: Int = 20
    ) async throws -> String {
        try verifyModelFiles(at: modelURL.path)

        let config = createConfig(modelURL: modelURL, modelName: modelName)
        let session = MLXSessionFactory.create()

        let preloadStream = await session.preload(configuration: config)
        for try await _ in preloadStream {
            // Consume progress updates
        }

        let input = createInput(prompt: prompt, maxTokens: maxTokens)
        let stream = await session.stream(input)
        let result = try await processStream(stream)

        #expect(result.hasReceivedText, "Should have received text")
        #expect(!result.text.isEmpty, "Text should not be empty")
        verifyMetrics(result.metrics)
        await session.unload()

        return result.text
    }

    // MARK: - Private Helpers

    private func createConfig(
        modelURL: URL,
        modelName: String
    ) -> ProviderConfiguration {
        ProviderConfiguration(
            location: modelURL,
            authentication: .noAuth,
            modelName: modelName,
            compute: .small
        )
    }

    private func createInput(
        prompt: String,
        maxTokens: Int
    ) -> LLMInput {
        LLMInput(
            context: prompt,
            sampling: SamplingParameters(
                temperature: 0.3,
                topP: 0.9,
                seed: 42
            ),
            limits: ResourceLimits(maxTokens: maxTokens)
        )
    }

    private func validateResult(
        _ result: StreamResult,
        expectedTokens: [String]
    ) {
        #expect(result.hasReceivedText, "Should have received text")
        #expect(!result.text.isEmpty, "Text should not be empty")

        if !expectedTokens.isEmpty {
            let lowercaseResult = result.text.lowercased()
            let hasExpectedToken = expectedTokens.contains { token in
                lowercaseResult.contains(token.lowercased())
            }
            #expect(
                hasExpectedToken || result.text.count >= 2,
                "Should generate text with \(expectedTokens) or 2+ chars. Got: '\(result.text)'"
            )
        }
    }

    private func isModelAvailable(at modelPath: String) -> Bool {
        let hasRequiredFiles = Self.requiredFiles.allSatisfy { file in
            FileManager.default.fileExists(atPath: modelPath + "/" + file)
        }
        let hasWeights = Self.weightFiles.contains { file in
            FileManager.default.fileExists(atPath: modelPath + "/" + file)
        }

        return hasRequiredFiles && hasWeights
    }
}
