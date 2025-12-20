import Abstractions
import Foundation
import Testing

@testable import AgentOrchestrator

/// Tests for the SteeringCoordinator actor
@Suite("SteeringCoordinator Tests")
internal struct SteeringCoordinatorTests {
    @Test("Initial state has no pending request")
    internal func initialStateHasNoPendingRequest() async {
        let coordinator: SteeringCoordinator = SteeringCoordinator()

        let hasPending: Bool = await coordinator.hasPendingRequest
        let current: SteeringRequest? = await coordinator.currentRequest

        #expect(!hasPending)
        #expect(current == nil)
    }

    @Test("Submit creates pending request")
    internal func submitCreatesPendingRequest() async {
        let coordinator: SteeringCoordinator = SteeringCoordinator()

        let request: SteeringRequest = await coordinator.submit(mode: .softInterrupt)

        let hasPending: Bool = await coordinator.hasPendingRequest
        let current: SteeringRequest? = await coordinator.currentRequest

        #expect(hasPending)
        #expect(current?.id == request.id)
        #expect(current?.mode == .softInterrupt)
    }

    @Test("Consume returns and clears request")
    internal func consumeReturnsAndClearsRequest() async {
        let coordinator: SteeringCoordinator = SteeringCoordinator()

        let submitted: SteeringRequest = await coordinator.submit(mode: .hardStop)
        let consumed: SteeringRequest? = await coordinator.consume()
        let hasPending: Bool = await coordinator.hasPendingRequest

        #expect(consumed?.id == submitted.id)
        #expect(!hasPending)
    }

    @Test("Consume returns nil when no request pending")
    internal func consumeReturnsNilWhenEmpty() async {
        let coordinator: SteeringCoordinator = SteeringCoordinator()

        let consumed: SteeringRequest? = await coordinator.consume()

        #expect(consumed == nil)
    }

    @Test("Clear removes pending request")
    internal func clearRemovesPendingRequest() async {
        let coordinator: SteeringCoordinator = SteeringCoordinator()

        await coordinator.submit(mode: .softInterrupt)
        await coordinator.clear()

        let hasPending: Bool = await coordinator.hasPendingRequest
        #expect(!hasPending)
    }

    @Test("Hard stop should interrupt immediately")
    internal func hardStopShouldInterruptImmediately() async {
        let coordinator: SteeringCoordinator = SteeringCoordinator()

        await coordinator.submit(mode: .hardStop)
        let shouldInterrupt: Bool = await coordinator.shouldInterruptImmediately()

        #expect(shouldInterrupt)
    }

    @Test("Soft interrupt should not interrupt immediately")
    internal func softInterruptShouldNotInterruptImmediately() async {
        let coordinator: SteeringCoordinator = SteeringCoordinator()

        await coordinator.submit(mode: .softInterrupt)
        let shouldInterrupt: Bool = await coordinator.shouldInterruptImmediately()

        #expect(!shouldInterrupt)
    }

    @Test("Hard stop should skip remaining tools")
    internal func hardStopShouldSkipTools() async {
        let coordinator: SteeringCoordinator = SteeringCoordinator()

        await coordinator.submit(mode: .hardStop)
        let shouldSkip: Bool = await coordinator.shouldSkipRemainingTools()

        #expect(shouldSkip)
    }

    @Test("Redirect should skip remaining tools")
    internal func redirectShouldSkipTools() async {
        let coordinator: SteeringCoordinator = SteeringCoordinator()

        await coordinator.submit(mode: .redirect("New prompt"))
        let shouldSkip: Bool = await coordinator.shouldSkipRemainingTools()

        #expect(shouldSkip)
    }

    @Test("Soft interrupt should not skip tools")
    internal func softInterruptShouldNotSkipTools() async {
        let coordinator: SteeringCoordinator = SteeringCoordinator()

        await coordinator.submit(mode: .softInterrupt)
        let shouldSkip: Bool = await coordinator.shouldSkipRemainingTools()

        #expect(!shouldSkip)
    }
}
