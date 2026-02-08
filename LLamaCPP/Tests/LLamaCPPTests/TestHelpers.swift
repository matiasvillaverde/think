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
        if let path = resolveModelPathFromEnvironment(variable: "LLAMACPP_TEST_MODEL_PATH") {
            return path
        }

        return resolveModelPathFromBundle(
            resourceName: "Resources/Qwen3-0.6B-UD-IQ1_S",
            withExtension: "gguf"
        )
    }

    /// Path to the higher quality BF16 model for acceptance tests
    internal static var acceptanceTestModelPath: String? {
        _ = environmentConfigured
        if let path = resolveModelPathFromEnvironment(variable: "LLAMACPP_ACCEPTANCE_MODEL_PATH") {
            return path
        }

        return resolveModelPathFromBundle(
            resourceName: "Resources/Qwen3-0.6B-BF16",
            withExtension: "gguf"
        )
    }

    internal static func requireTestModelPath(
        file _: StaticString = #file,
        line _: UInt = #line
    ) throws -> String {
        guard let path = testModelPath else {
            throw TestSkip(
                """
                LLamaCPP unit-test model not available.

                Set LLAMACPP_TEST_MODEL_PATH to a local .gguf file, or download one into:
                LLamaCPP/Tests/LLamaCPPTests/Resources/

                Helper:
                bash LLamaCPP/Tests/LLamaCPPTests/Resources/download.sh
                """
            )
        }
        return path
    }

    internal static func requireAcceptanceTestModelPath(
        file _: StaticString = #file,
        line _: UInt = #line
    ) throws -> String {
        guard let path = acceptanceTestModelPath else {
            throw TestSkip(
                """
                LLamaCPP acceptance-test model not available.

                Set LLAMACPP_ACCEPTANCE_MODEL_PATH to a local .gguf file, or download one into:
                LLamaCPP/Tests/LLamaCPPTests/Resources/

                Helper:
                bash LLamaCPP/Tests/LLamaCPPTests/Resources/download.sh
                """
            )
        }
        return path
    }

    internal static func createTestModel(path: String) throws -> LlamaCPPModel {
        let configuration: ComputeConfigurationExtended = .cpuOnly(contextSize: testContextSize)
        return try LlamaCPPModel(path: path, configuration: configuration)
    }

    internal static func createTestConfiguration() throws -> ProviderConfiguration {
        let modelPath: String = try requireTestModelPath()

        return ProviderConfiguration(
            location: URL(fileURLWithPath: modelPath),
            authentication: .noAuth,
            modelName: "test-model",
            compute: .small  // Use small configuration for tests
        )
    }

    /// Create configuration for acceptance tests with higher quality model
    internal static func createAcceptanceTestConfiguration() throws -> ProviderConfiguration {
        let modelPath: String = try requireAcceptanceTestModelPath()

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

    private static func resolveModelPathFromEnvironment(variable: String) -> String? {
        guard let raw: String = ProcessInfo.processInfo.environment[variable], !raw.isEmpty else {
            return nil
        }

        let expanded: String = expandTilde(in: raw)
        let url: URL = URL(fileURLWithPath: expanded)

        guard FileManager.default.fileExists(atPath: url.path) else {
            return nil
        }
        guard isValidGGUF(at: url) else {
            return nil
        }
        return url.path
    }

    private static func resolveModelPathFromBundle(
        resourceName: String,
        withExtension ext: String
    ) -> String? {
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

    private static func expandTilde(in path: String) -> String {
        let tilde: String = "~"
        let tildeSlash: String = "~/"
        let tildeSlashPrefixLength: Int = 2

        guard path.hasPrefix("~") else {
            return path
        }

        let home: String = FileManager.default.homeDirectoryForCurrentUser.path
        if path == tilde {
            return home
        }
        if path.hasPrefix(tildeSlash) {
            return home + "/" + String(path.dropFirst(tildeSlashPrefixLength))
        }
        return path
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
