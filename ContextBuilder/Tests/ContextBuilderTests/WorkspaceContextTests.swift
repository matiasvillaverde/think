import Abstractions
@testable import ContextBuilder
import Foundation
import Testing

@Suite("ContextBuilder Workspace Context Tests")
internal struct WorkspaceContextTests {
    @Test("Workspace context is injected into system prompt")
    func workspaceContextInjected() async throws {
        let tooling = TestTooling(definitions: [])
        let contextBuilder = ContextBuilder(tooling: tooling)

        let workspaceContext = WorkspaceContext(sections: [
            WorkspaceContextSection(
                title: "AGENTS.md",
                content: "Follow repository instructions."
            ),
            WorkspaceContextSection(
                title: "TOOLS.md",
                content: "Use tools responsibly."
            )
        ])

        let contextConfig = ContextConfiguration(
            systemInstruction: "System prompt",
            contextMessages: [],
            maxPrompt: 1_024,
            reasoningLevel: nil,
            includeCurrentDate: false,
            knowledgeCutoffDate: nil,
            currentDateOverride: nil,
            memoryContext: nil,
            skillContext: nil,
            workspaceContext: workspaceContext,
            allowedTools: [],
            hasToolPolicy: false
        )

        let model = SendableModel(
            id: UUID(),
            ramNeeded: 1_024,
            modelType: .language,
            location: "test/model",
            architecture: .phi,
            backend: .mlx
        )

        let parameters = BuildParameters(
            action: .textGeneration([]),
            contextConfiguration: contextConfig,
            toolResponses: [],
            model: model
        )

        let context = try await contextBuilder.build(parameters: parameters)

        #expect(context.contains("# Workspace Context"))
        #expect(context.contains("## AGENTS.md"))
        #expect(context.contains("Follow repository instructions."))
        #expect(context.contains("## TOOLS.md"))
        #expect(context.contains("Use tools responsibly."))
    }

    @Test("Workspace context is omitted when nil")
    func workspaceContextOmittedWhenNil() async throws {
        let tooling = TestTooling(definitions: [])
        let contextBuilder = ContextBuilder(tooling: tooling)

        let contextConfig = ContextConfiguration(
            systemInstruction: "System prompt",
            contextMessages: [],
            maxPrompt: 1_024,
            reasoningLevel: nil,
            includeCurrentDate: false,
            knowledgeCutoffDate: nil,
            currentDateOverride: nil,
            memoryContext: nil,
            skillContext: nil,
            workspaceContext: nil,
            allowedTools: [],
            hasToolPolicy: false
        )

        let model = SendableModel(
            id: UUID(),
            ramNeeded: 1_024,
            modelType: .language,
            location: "test/model",
            architecture: .phi,
            backend: .mlx
        )

        let parameters = BuildParameters(
            action: .textGeneration([]),
            contextConfiguration: contextConfig,
            toolResponses: [],
            model: model
        )

        let context = try await contextBuilder.build(parameters: parameters)

        #expect(!context.contains("# Workspace Context"))
        #expect(!context.contains("AGENTS.md"))
    }
}
