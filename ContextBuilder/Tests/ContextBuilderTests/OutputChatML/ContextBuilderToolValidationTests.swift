import Abstractions
@testable import ContextBuilder
import Foundation
import Testing

/// Tests for ContextBuilder tool validation error handling
@Suite("ContextBuilder Tool Validation Tests")
internal struct ContextBuilderToolValidationTests {
    @Test(
        "ContextBuilder throws error when requested tool is not available in tooling",
        arguments: [
            Architecture.yi,
            Architecture.phi,
            Architecture.phi4,
            Architecture.baichuan,
            Architecture.chatglm,
            Architecture.smol,
            Architecture.falcon,
            Architecture.gemma
        ]
    )
    func testToolNotAvailableError(architecture: Architecture) async throws {
        let tooling = MockTooling() // Returns no tools
        let contextBuilder = ContextBuilder(tooling: tooling)

        let model = SendableModel(
            id: UUID(),
            ramNeeded: 1_000_000_000,
            modelType: .language,
            location: "test-model",
            architecture: architecture
        )

        let messages = [
            MessageData(
                id: UUID(),
                createdAt: Date(),
                userInput: "What's the weather like?",
            )
        ]

        let contextConfig = ContextConfiguration(
            systemInstruction: "You are a helpful assistant.",
            contextMessages: messages,
            maxPrompt: 4_096,
            reasoningLevel: "basic",
            includeCurrentDate: false
        )

        // Request weather tool but MockTooling provides no tools
        let parameters = BuildParameters(
            action: .textGeneration([.weather]), // This should fail
            contextConfiguration: contextConfig,
            toolResponses: [],
            model: model
        )

        // Expect specific error with exact tool information
        await #expect(throws: ContextBuilderError.toolsNotAvailable(
            requested: [.weather],
            missing: [.weather]
        )) {
            _ = try await contextBuilder.build(parameters: parameters)
        }
    }

    @Test(
        "ContextBuilder throws error when multiple requested tools are not available",
        arguments: [
            Architecture.yi,
            Architecture.phi,
            Architecture.phi4,
            Architecture.baichuan,
            Architecture.chatglm,
            Architecture.smol,
            Architecture.falcon
        ]
    )
    func testMultipleToolsNotAvailableError(architecture: Architecture) async throws {
        let tooling = MockTooling() // Returns no tools
        let contextBuilder = ContextBuilder(tooling: tooling)

        let model = SendableModel(
            id: UUID(),
            ramNeeded: 1_000_000_000,
            modelType: .language,
            location: "test-model",
            architecture: architecture
        )

        let messages = [
            MessageData(
                id: UUID(),
                createdAt: Date(),
                userInput: "Search and get weather",
            )
        ]

        let contextConfig = ContextConfiguration(
            systemInstruction: "You are a helpful assistant.",
            contextMessages: messages,
            maxPrompt: 4_096,
            reasoningLevel: "basic",
            includeCurrentDate: false
        )

        // Request multiple tools but MockTooling provides none
        let parameters = BuildParameters(
            action: .textGeneration([.weather, .browser, .python]),
            contextConfiguration: contextConfig,
            toolResponses: [],
            model: model
        )

        // Expect error with all missing tools
        await #expect(throws: ContextBuilderError.toolsNotAvailable(
            requested: [.weather, .browser, .python],
            missing: [.weather, .browser, .python]
        )) {
            _ = try await contextBuilder.build(parameters: parameters)
        }
    }

    @Test(
        "ContextBuilder succeeds when no tools are requested",
        arguments: [
            Architecture.yi,
            Architecture.phi,
            Architecture.phi4,
            Architecture.baichuan,
            Architecture.chatglm,
            Architecture.smol,
            Architecture.falcon
        ]
    )
    func testNoToolsRequestedSucceeds(architecture: Architecture) async throws {
        let tooling = MockTooling() // Returns no tools
        let contextBuilder = ContextBuilder(tooling: tooling)

        let model = SendableModel(
            id: UUID(),
            ramNeeded: 1_000_000_000,
            modelType: .language,
            location: "test-model",
            architecture: architecture
        )

        let messages = [
            MessageData(
                id: UUID(),
                createdAt: Date(),
                userInput: "Hello world",
            )
        ]

        let contextConfig = ContextConfiguration(
            systemInstruction: "You are a helpful assistant.",
            contextMessages: messages,
            maxPrompt: 4_096,
            reasoningLevel: "basic",
            includeCurrentDate: false
        )

        // No tools requested - should succeed even with empty tooling
        let parameters = BuildParameters(
            action: .textGeneration([]), // Empty tools - should work
            contextConfiguration: contextConfig,
            toolResponses: [],
            model: model
        )

        // Should not throw any error
        let result = try await contextBuilder.build(parameters: parameters)
        #expect(!result.isEmpty, "Context should be generated successfully")
        #expect(!result.contains("Tools Available"), "No tools section should be present")
    }

    @Test("ContextBuilder error provides meaningful description")
    func testErrorDescription() {
        let error = ContextBuilderError.toolsNotAvailable(
            requested: [.weather, .browser],
            missing: [.weather]
        )

        let description = error.errorDescription ?? ""
        #expect(description.contains("Weather"), "Error should mention the missing tool")
        #expect(description.contains("Browser"), "Error should mention requested tools")

        let failureReason = error.failureReason ?? ""
        #expect(failureReason.contains("Weather"), "Failure reason should specify missing tool")

        let recovery = error.recoverySuggestion ?? ""
        #expect(recovery.contains("Weather"), "Recovery should mention missing tool")
    }
}
