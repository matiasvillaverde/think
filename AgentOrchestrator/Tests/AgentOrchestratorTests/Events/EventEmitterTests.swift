import Abstractions
import Foundation
import Testing

@testable import AgentOrchestrator

/// Tests for the EventEmitter actor that manages event emission during agent generation
@Suite("EventEmitter Tests")
internal struct EventEmitterTests {
    // MARK: - Generation Lifecycle Events

    @Test("Generation started event emits correctly")
    internal func generationStartedEmitsEvent() async {
        let emitter: EventEmitter = EventEmitter()
        let runId: UUID = UUID()

        await emitter.emitGenerationStarted(runId: runId)
        await emitter.finish()

        var events: [AgentEvent] = []
        for await event in await emitter.eventStream { events.append(event) }

        #expect(events.count == 1)
        if case .generationStarted(let capturedRunId) = events.first {
            #expect(capturedRunId == runId)
        } else {
            Issue.record("Expected generationStarted event")
        }
    }

    @Test("Generation completed event includes duration")
    internal func generationCompletedIncludesDuration() async throws {
        let emitter: EventEmitter = EventEmitter()
        let runId: UUID = UUID()

        await emitter.emitGenerationStarted(runId: runId)
        try await Task.sleep(for: .milliseconds(10))
        await emitter.emitGenerationCompleted(runId: runId)
        await emitter.finish()

        var events: [AgentEvent] = []
        for await event in await emitter.eventStream { events.append(event) }

        #expect(events.count == 2)
        if case let .generationCompleted(capturedRunId, durationMs) = events.last {
            #expect(capturedRunId == runId)
            #expect(durationMs >= 0)
        } else {
            Issue.record("Expected generationCompleted event")
        }
    }

    @Test("Generation failed event captures error description")
    internal func generationFailedCapturesError() async {
        let emitter: EventEmitter = EventEmitter()
        let runId: UUID = UUID()
        let testError: NSError = NSError(
            domain: "TestError",
            code: 42,
            userInfo: [NSLocalizedDescriptionKey: "Test error message"]
        )

        await emitter.emitGenerationFailed(runId: runId, error: testError)
        await emitter.finish()

        var events: [AgentEvent] = []
        for await event in await emitter.eventStream { events.append(event) }

        #expect(events.count == 1)
        if case let .generationFailed(capturedRunId, errorMessage) = events.first {
            #expect(capturedRunId == runId)
            #expect(errorMessage == "Test error message")
        } else {
            Issue.record("Expected generationFailed event")
        }
    }

    // MARK: - Tool Events

    @Test("Tool started event captures request ID and name")
    internal func toolStartedEmitsCorrectData() async {
        let emitter: EventEmitter = EventEmitter()
        let requestId: UUID = UUID()
        let toolName: String = "calculator"

        await emitter.emitToolStarted(requestId: requestId, toolName: toolName)
        await emitter.finish()

        var events: [AgentEvent] = []
        for await event in await emitter.eventStream { events.append(event) }

        #expect(events.count == 1)
        if case let .toolStarted(capturedId, capturedName) = events.first {
            #expect(capturedId == requestId)
            #expect(capturedName == toolName)
        } else {
            Issue.record("Expected toolStarted event")
        }
    }

    @Test("Tool completed event captures result and duration")
    internal func toolCompletedEmitsCorrectData() async {
        let emitter: EventEmitter = EventEmitter()
        let requestId: UUID = UUID()
        let result: String = "42"
        let durationMs: Int = 150

        await emitter.emitToolCompleted(requestId: requestId, result: result, durationMs: durationMs)
        await emitter.finish()

        var events: [AgentEvent] = []
        for await event in await emitter.eventStream { events.append(event) }

        #expect(events.count == 1)
        if case let .toolCompleted(id, res, dur) = events.first {
            #expect(id == requestId)
            #expect(res == result)
            #expect(dur == durationMs)
        } else {
            Issue.record("Expected toolCompleted event")
        }
    }

    @Test("Finish ends the event stream")
    internal func finishEndsStream() async {
        let emitter: EventEmitter = EventEmitter()

        await emitter.emitTextDelta(text: "Test")
        await emitter.finish()

        var eventCount: Int = 0
        for await _ in await emitter.eventStream { eventCount += 1 }

        #expect(eventCount == 1)
    }
}
