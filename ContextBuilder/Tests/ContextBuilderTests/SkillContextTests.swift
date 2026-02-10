import Abstractions
@testable import ContextBuilder
import Foundation
import Testing

@Suite("ContextBuilder Skill Context Tests")
internal struct SkillContextTests {
    @Test("Skill context is injected when matching tools are available")
    func skillContextInjectedForMatchingTools() async throws {
        let tooling = TestTooling(
            definitions: [Self.weatherToolDefinition]
        )
        let contextBuilder = ContextBuilder(tooling: tooling)

        let skill = SkillData(
            id: UUID(),
            createdAt: Date(),
            updatedAt: Date(),
            name: "Weather Skill",
            skillDescription: "Provide weather guidance",
            instructions: "Use the weather tool and summarize the forecast.",
            tools: [ToolIdentifier.weather.toolName],
            isSystem: true,
            isEnabled: true,
            chatId: nil
        )

        let contextConfig = ContextConfiguration(
            systemInstruction: "System prompt",
            contextMessages: [],
            maxPrompt: 1_024,
            includeCurrentDate: false,
            knowledgeCutoffDate: nil,
            currentDateOverride: nil,
            memoryContext: nil,
            skillContext: SkillContext(activeSkills: [skill]),
            allowedTools: [.weather],
            hasToolPolicy: true
        )

        let model = SendableModel(
            id: UUID(),
            ramNeeded: 1_024,
            modelType: .language,
            location: "test/model",
            architecture: .phi,
            backend: .mlx,
            locationKind: .huggingFace,
        )

        let parameters = BuildParameters(
            action: .textGeneration([.weather]),
            contextConfiguration: contextConfig,
            toolResponses: [],
            model: model
        )

        let context = try await contextBuilder.build(parameters: parameters)

        #expect(context.contains("# Skills"))
        #expect(context.contains("## Weather Skill"))
        #expect(context.contains("Use the weather tool and summarize the forecast."))
    }

    @Test("Skill context is not injected when no tools are available")
    func skillContextNotInjectedWithoutTools() async throws {
        let tooling = TestTooling(definitions: [])
        let contextBuilder = ContextBuilder(tooling: tooling)

        let skill = SkillData(
            id: UUID(),
            createdAt: Date(),
            updatedAt: Date(),
            name: "General Skill",
            skillDescription: "General instructions",
            instructions: "You must follow this guidance.",
            tools: [ToolIdentifier.weather.toolName],
            isSystem: true,
            isEnabled: true,
            chatId: nil
        )

        let contextConfig = ContextConfiguration(
            systemInstruction: "System prompt",
            contextMessages: [],
            maxPrompt: 1_024,
            includeCurrentDate: false,
            knowledgeCutoffDate: nil,
            currentDateOverride: nil,
            memoryContext: nil,
            skillContext: SkillContext(activeSkills: [skill]),
            allowedTools: [],
            hasToolPolicy: true
        )

        let model = SendableModel(
            id: UUID(),
            ramNeeded: 1_024,
            modelType: .language,
            location: "test/model",
            architecture: .phi,
            backend: .mlx,
            locationKind: .huggingFace,
        )

        let parameters = BuildParameters(
            action: .textGeneration([]),
            contextConfiguration: contextConfig,
            toolResponses: [],
            model: model
        )

        let context = try await contextBuilder.build(parameters: parameters)

        #expect(!context.contains("# Skills"))
        #expect(!context.contains("General Skill"))
    }

    private static let weatherToolDefinition: ToolDefinition = ToolDefinition(
        name: ToolIdentifier.weather.toolName,
        description: "Get weather information",
        schema: "{}"
    )
}
