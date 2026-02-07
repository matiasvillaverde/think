import Abstractions
import ContextBuilder
import Foundation
import Testing
@testable import RemoteSession

/// Integration tests for OpenRouter provider.
///
/// These tests require an OPENROUTER_API_KEY environment variable.
/// To run: `infisical run --env=development -- swift test --filter Integration`
@Suite("OpenRouter Integration", .tags(.integration))
struct OpenRouterIntegrationTests {
    @Test("Stream from free model via OpenRouter")
    func testOpenRouterStreaming() async throws {
        guard let apiKey = ProcessInfo.processInfo.environment["OPENROUTER_API_KEY"] else {
            throw TestSkip("OPENROUTER_API_KEY not set")
        }

        // Create mock API key manager with the key
        let apiKeyManager = MockAPIKeyManager(keys: [.openRouter: apiKey])
        let session = RemoteSession(apiKeyManager: apiKeyManager)

        // Create configuration for a free model
        // Using Gemma 3n which is a reliable free model on OpenRouter
        let configuration = ProviderConfiguration(
            location: URL(fileURLWithPath: "/"),
            authentication: .noAuth,
            modelName: "openrouter:google/gemma-3n-e2b-it:free",
            compute: .init(contextSize: 4096, batchSize: 512, threadCount: 4)
        )

        // Preload (validates API key)
        for try await _ in await session.preload(configuration: configuration) {
            // Progress updates are ignored for tests
        }

        // Create input
        let input = LLMInput(
            context: "Say hello in exactly 3 words.",
            sampling: SamplingParameters(temperature: 0.7, topP: 0.9),
            limits: ResourceLimits(maxTokens: 50)
        )

        // Stream response
        var text = ""
        for try await chunk in await session.stream(input) {
            text += chunk.text
        }

        #expect(!text.isEmpty, "Expected non-empty response")
        print("Response: \(text)")
    }

    @Test("Stream tool call payload and parse")
    func testToolCallParsing() async throws {
        guard let apiKey = ProcessInfo.processInfo.environment["OPENROUTER_API_KEY"] else {
            throw TestSkip("OPENROUTER_API_KEY not set")
        }

        let apiKeyManager = MockAPIKeyManager(keys: [.openRouter: apiKey])
        let session = RemoteSession(apiKeyManager: apiKeyManager)

        let configuration = ProviderConfiguration(
            location: URL(fileURLWithPath: "/"),
            authentication: .noAuth,
            modelName: "openrouter:google/gemma-3n-e2b-it:free",
            compute: .init(contextSize: 4096, batchSize: 512, threadCount: 4)
        )

        for try await _ in await session.preload(configuration: configuration) {
            // Progress updates are ignored for tests
        }

        let payload = [
            "<tool_call>{\"tool_calls\":[{\"id\":\"call_1\",\"type\":\"function\",",
            "\"function\":{\"name\":\"workspace.write\",\"arguments\":{\"action\":\"write\",",
            "\"path\":\"notes.md\",\"content\":\"Hello\"}}}]}</tool_call>"
        ].joined()
        let input = LLMInput(
            context: """
You are a strict formatter. Output exactly the following and nothing else:
\(payload)
""",
            sampling: .deterministic,
            limits: ResourceLimits(maxTokens: 200)
        )

        var text = ""
        for try await chunk in await session.stream(input) {
            text += chunk.text
        }

        let contextBuilder = ContextBuilder(tooling: StubTooling())
        let model = SendableModel(
            id: UUID(),
            ramNeeded: 1_000_000_000,
            modelType: .language,
            location: "test-model",
            architecture: .llama,
            locationKind: .huggingFace,
        )

        let result = try await contextBuilder.process(output: text, model: model)
        let toolRequests = result.channels.compactMap(\.toolRequest)

        #expect(!toolRequests.isEmpty)
        #expect(toolRequests.first?.name == "workspace")
        #expect(toolRequests.first?.arguments.contains("notes.md") == true)
    }

    @Test("Handle invalid API key")
    func testInvalidKey() async throws {
        let apiKeyManager = MockAPIKeyManager(keys: [.openRouter: "invalid-key"])
        let session = RemoteSession(apiKeyManager: apiKeyManager)

        let configuration = ProviderConfiguration(
            location: URL(fileURLWithPath: "/"),
            authentication: .noAuth,
            modelName: "openrouter:google/gemma-3n-e2b-it:free",
            compute: .init(contextSize: 4096, batchSize: 512, threadCount: 4)
        )

        for try await _ in await session.preload(configuration: configuration) {
            // Progress updates are ignored for tests
        }

        let input = LLMInput(
            context: "Hello",
            sampling: .default,
            limits: .default
        )

        do {
            for try await _ in await session.stream(input) {
                // Consume stream chunks
            }
            #expect(Bool(false), "Expected error for invalid API key")
        } catch {
            // Expected - should get an authentication error
            #expect(Bool(true))
        }
    }
}

/// Skip error for tests that require API keys.
struct TestSkip: Error, CustomStringConvertible {
    let reason: String

    init(_ reason: String) {
        self.reason = reason
    }

    var description: String { reason }
}

/// Tag for integration tests.
extension Tag {
    @Tag static var integration: Self
}

private actor StubTooling: Tooling {
    func configureTool(identifiers _: Set<ToolIdentifier>) async {
        // no-op
    }
    func clearTools() async {
        // no-op
    }
    func getToolDefinitions(for _: Set<ToolIdentifier>) async -> [ToolDefinition] {
        // no-op
        []
    }
    func getAllToolDefinitions() async -> [ToolDefinition] {
        // no-op
        []
    }
    func executeTools(toolRequests _: [ToolRequest]) async -> [ToolResponse] {
        // no-op
        []
    }
    func configureSemanticSearch(
        database _: DatabaseProtocol,
        chatId _: UUID,
        fileTitles _: [String]
    ) async {
        // no-op
    }
}
