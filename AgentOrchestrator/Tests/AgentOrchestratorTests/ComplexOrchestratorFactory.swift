import Abstractions
import AbstractionsTestUtilities
@testable import AgentOrchestrator
import ContextBuilder
import Database
import Foundation
import Tools

internal enum ComplexOrchestratorFactory {
    internal static func createOrchestratorWithMocks(
        database: Database
    ) async -> (AgentOrchestrator, MockLLMSession) {
        let mockSession: MockLLMSession = MockLLMSession()
        let toolManager: ToolManager = await createToolManager()
        let coordinator: ModelStateCoordinator = createModelCoordinator(
            database: database,
            mockSession: mockSession
        )
        let persistor: MessagePersistor = MessagePersistor(database: database)
        let contextBuilder: ContextBuilder = ContextBuilder(tooling: toolManager)

        let orchestrator: AgentOrchestrator = AgentOrchestrator(
            modelCoordinator: coordinator,
            persistor: persistor,
            contextBuilder: contextBuilder,
            tooling: toolManager
        )

        return (orchestrator, mockSession)
    }

    private static func createToolManager() async -> ToolManager {
        let toolManager: ToolManager = ToolManager()
        await toolManager.registerStrategy(ComplexWeatherStrategy())
        await toolManager.registerStrategy(ComplexLocationStrategy())
        await toolManager.registerStrategy(ComplexCalculatorStrategy())
        await toolManager.registerStrategy(ComplexCalendarStrategy())
        await toolManager.registerStrategy(ComplexNewsStrategy())
        return toolManager
    }

    private static func createModelCoordinator(
        database: Database,
        mockSession: MockLLMSession
    ) -> ModelStateCoordinator {
        let mockDownloader: MockModelDownloader = MockModelDownloader()
        mockDownloader.configureForStandardTests()

        return ModelStateCoordinator(
            database: database,
            mlxSession: mockSession,
            ggufSession: MockLLMSession(),
            imageGenerator: MockImageGenerating(),
            modelDownloader: mockDownloader
        )
    }
}
