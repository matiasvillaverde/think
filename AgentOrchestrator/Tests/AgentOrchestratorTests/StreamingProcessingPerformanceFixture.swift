import Abstractions
import AbstractionsTestUtilities
@testable import AgentOrchestrator
import ContextBuilder
@testable import Database
import Foundation
import Tools

internal struct StreamingProcessingPerformanceFixture {
    internal static let expectedProcessCalls: Int = 2
    private static let chunkText: String = "token "
    private static let chunkRepeatCount: Int = 60
    private static let delayBetweenChunks: TimeInterval = 0.02

    internal let orchestrator: AgentOrchestrator
    internal let chatId: UUID
    internal let counting: CountingContextBuilder

    internal static func make() async throws -> Self {
        let database: Database = try await AgentOrchestratorTestHelpers.createTestDatabase()
        let chatId: UUID = try await AgentOrchestratorTestHelpers.setupChatWithModel(database)

        let mlxSession: MockLLMSession = await makeMockSession()
        let counting: CountingContextBuilder = makeCountingContextBuilder()

        let orchestrator: AgentOrchestrator = AgentOrchestratorTestHelpers.createOrchestrator(
            database: database,
            mlxSession: mlxSession,
            contextBuilder: counting
        )

        return Self(orchestrator: orchestrator, chatId: chatId, counting: counting)
    }

    private static func makeMockSession() async -> MockLLMSession {
        let mlxSession: MockLLMSession = MockLLMSession()
        await mlxSession.configureForAlreadyLoaded()

        let chunks: [String] = Array(repeating: chunkText, count: chunkRepeatCount)
        await mlxSession.setSequentialStreamResponses([
            .text(chunks, delayBetweenChunks: delayBetweenChunks)
        ])

        return mlxSession
    }

    private static func makeCountingContextBuilder() -> CountingContextBuilder {
        let toolManager: ToolManager = ToolManager()
        let realContextBuilder: ContextBuilder = ContextBuilder(tooling: toolManager)
        return CountingContextBuilder(wrapping: realContextBuilder)
    }
}
