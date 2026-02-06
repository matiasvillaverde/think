import Abstractions
import Darwin
import Foundation
@testable import LLamaCPP

internal enum TestHelpers {
    private static let ggufMagic: Data = Data("GGUF".utf8)

    private static let testContextSize: Int = 2_048

    private static let environmentConfigured: Void = {
        setenv("LLAMA_CPP_FORCE_CPU", "1", 1)
    }()

    internal static var testModelPath: String? {
        _ = environmentConfigured
        return resolveModelPath(
            resourceName: "Resources/Qwen3-0.6B-UD-IQ1_S",
            withExtension: "gguf"
        )
    }

    /// Path to the higher quality BF16 model for acceptance tests
    internal static var acceptanceTestModelPath: String? {
        _ = environmentConfigured
        return resolveModelPath(
            resourceName: "Resources/Qwen3-0.6B-BF16",
            withExtension: "gguf"
        )
    }

    internal static func createTestModel(path: String) throws -> LlamaCPPModel {
        let configuration: ComputeConfigurationExtended = .cpuOnly(contextSize: testContextSize)
        return try LlamaCPPModel(path: path, configuration: configuration)
    }

    internal static func createTestConfiguration() -> ProviderConfiguration? {
        guard let modelPath = testModelPath else {
            return nil
        }

        return ProviderConfiguration(
            location: URL(fileURLWithPath: modelPath),
            authentication: .noAuth,
            modelName: "test-model",
            compute: .small  // Use small configuration for tests
        )
    }

    /// Create configuration for acceptance tests with higher quality model
    internal static func createAcceptanceTestConfiguration() -> ProviderConfiguration? {
        guard let modelPath = acceptanceTestModelPath else {
            return nil
        }

        return ProviderConfiguration(
            location: URL(fileURLWithPath: modelPath),
            authentication: .noAuth,
            modelName: "qwen3-0.6b-bf16",
            compute: .medium  // Use medium configuration for acceptance tests
        )
    }

    internal static func createTestInput(
        context: String = "Hello",
        maxTokens: Int = 3,
        temperature: Float = 0.0
    ) -> LLMInput {
        LLMInput(
            context: context,
            sampling: SamplingParameters(temperature: temperature, topP: 1.0),
            limits: ResourceLimits(maxTokens: maxTokens)
        )
    }

    internal static func collectChunks(
        from stream: AsyncThrowingStream<LLMStreamChunk, Error>,
        limit: Int
    ) async throws -> [LLMStreamChunk] {
        var chunks: [LLMStreamChunk] = []
        for try await chunk in stream {
            chunks.append(chunk)
            if chunks.count >= limit {
                break
            }
        }
        return chunks
    }

    private static func resolveModelPath(resourceName: String, withExtension ext: String) -> String? {
        guard let url = Bundle.module.url(
            forResource: resourceName,
            withExtension: ext
        ) else {
            return nil
        }

        guard isValidGGUF(at: url) else {
            return nil
        }

        return url.path
    }

    private static func isValidGGUF(at url: URL) -> Bool {
        guard let handle = try? FileHandle(forReadingFrom: url) else {
            return false
        }
        defer { try? handle.close() }

        let header: Data? = try? handle.read(upToCount: ggufMagic.count)
        return header == ggufMagic
    }
}
