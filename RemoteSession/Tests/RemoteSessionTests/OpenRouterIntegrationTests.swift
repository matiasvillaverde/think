import Abstractions
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
