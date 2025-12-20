import Abstractions
import AbstractionsTestUtilities
@testable import AgentOrchestrator
@testable import Database
import Foundation
import Testing

@Suite("AgentOrchestratorFactory Tests")
internal struct AgentOrchestratorFactoryTests {
    @Test("Factory returns singleton instance")
    @MainActor
    internal func testFactoryReturnsSingleton() throws {
        // Reset to ensure clean state
        AgentOrchestratorFactory.reset()

        let database: Database = try createTestDatabase()
        let mlxSession: MockLLMSession = MockLLMSession()
        let ggufSession: MockLLMSession = MockLLMSession()

        // Get first instance
        let instance1: AgentOrchestrating = AgentOrchestratorFactory.shared(
            database: database,
            mlxSession: mlxSession,
            ggufSession: ggufSession
        )

        // Get second instance
        let instance2: AgentOrchestrating = AgentOrchestratorFactory.shared(
            database: database,
            mlxSession: mlxSession,
            ggufSession: ggufSession
        )

        // Verify they are the same instance
        #expect(instance1 === instance2)
    }

    @Test("Factory creates instance lazily")
    @MainActor
    internal func testFactoryCreatesInstanceLazily() throws {
        // Reset to ensure no instance exists
        AgentOrchestratorFactory.reset()

        let database: Database = try createTestDatabase()
        let mlxSession: MockLLMSession = MockLLMSession()
        let ggufSession: MockLLMSession = MockLLMSession()

        // Get instance - should create it
        let instance: AgentOrchestrating = AgentOrchestratorFactory.shared(
            database: database,
            mlxSession: mlxSession,
            ggufSession: ggufSession
        )

        // Verify instance is created successfully
        let _: AgentOrchestrating = instance
    }

    // Test for custom context builder removed as it's no longer a parameter

    @Test("Factory reset clears singleton")
    @MainActor
    internal func testFactoryResetClearsSingleton() throws {
        let database: Database = try createTestDatabase()

        // Get first instance
        let mlxSession1: MockLLMSession = MockLLMSession()
        let ggufSession1: MockLLMSession = MockLLMSession()
        let instance1: AgentOrchestrating = AgentOrchestratorFactory.shared(
            database: database,
            mlxSession: mlxSession1,
            ggufSession: ggufSession1
        )

        // Reset factory
        AgentOrchestratorFactory.reset()

        // Get new instance after reset
        let mlxSession2: MockLLMSession = MockLLMSession()
        let ggufSession2: MockLLMSession = MockLLMSession()
        let instance2: AgentOrchestrating = AgentOrchestratorFactory.shared(
            database: database,
            mlxSession: mlxSession2,
            ggufSession: ggufSession2
        )

        // They should be different instances
        #expect(instance1 !== instance2)
    }

    @Test("AgentOrchestrating protocol is accessible")
    internal func testAgentOrchestratingProtocolIsAccessible() {
        // This test ensures the protocol is public and accessible
        // The fact that we can reference AgentOrchestrating proves it's public
        _ = AgentOrchestrating.self
    }

    @Test("ModelStateCoordinatorError is accessible")
    internal func testModelStateCoordinatorErrorIsAccessible() {
        // This test ensures the error enum is public and accessible
        let error: ModelStateCoordinatorError = .noChatLoaded
        #expect(error.errorDescription != nil)
    }

    @Test("Factory creates working orchestrator")
    @MainActor
    internal func testFactoryCreatesWorkingOrchestrator() async throws {
        // Reset to ensure clean state
        AgentOrchestratorFactory.reset()

        let database: Database = try createTestDatabase()
        let mlxSession: MockLLMSession = MockLLMSession()
        let ggufSession: MockLLMSession = MockLLMSession()
        let orchestrator: AgentOrchestrating = AgentOrchestratorFactory.shared(
            database: database,
            mlxSession: mlxSession,
            ggufSession: ggufSession
        )

        // Try to generate without loading - should throw error
        await #expect(throws: ModelStateCoordinatorError.noChatLoaded) {
            try await orchestrator.generate(prompt: "Test", action: .textGeneration([]))
        }
    }

    // MARK: - Helper Methods

    private func createTestDatabase() throws -> Database {
        try Database.new(
            configuration: DatabaseConfiguration(
                isStoredInMemoryOnly: true,
                allowsSave: true,
                ragFactory: MockRagFactory(mockRag: MockRagging())
            )
        )
    }
}
