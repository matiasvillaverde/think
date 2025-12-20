import Abstractions
import Foundation

/// Mock implementation of AgentOrchestrating for testing
public actor MockAgentOrchestrator: AgentOrchestrating {
    // MARK: - Call Tracking

    public struct MethodCall: Equatable, Sendable {
        public let method: String
        public let timestamp: Date
    }

    private var methodCalls: [MethodCall] = []

    // MARK: - State

    public private(set) var currentChatId: UUID?
    public private(set) var isLoaded: Bool = false
    public private(set) var isGenerating: Bool = false

    // MARK: - Event Stream

    private var eventContinuation: AsyncStream<AgentEvent>.Continuation?
    private var _eventStream: AgentEventStream

    // swiftlint:disable async_without_await
    /// The stream of events emitted during generation
    public var eventStream: AgentEventStream {
        get async { _eventStream }
    }
    // swiftlint:enable async_without_await

    // MARK: - Method-Specific Call Tracking

    public private(set) var loadCalls: [(chatId: UUID, timestamp: Date)] = []
    public private(set) var unloadCalls: [Date] = []
    public private(set) var generateCalls: [(prompt: String, action: Action, timestamp: Date)] = []
    public private(set) var stopCalls: [Date] = []
    public private(set) var steerCalls: [(mode: SteeringMode, timestamp: Date)] = []
    public private(set) var currentSteeringMode: SteeringMode = .inactive

    // MARK: - Mock Configuration

    public var shouldThrowOnLoad: Error?
    public var shouldThrowOnUnload: Error?
    public var shouldThrowOnGenerate: Error?
    public var shouldThrowOnStop: Error?

    public var generateDelay: TimeInterval = 0

    // MARK: - Initialization

    public init() {
        var continuation: AsyncStream<AgentEvent>.Continuation?
        self._eventStream = AsyncStream<AgentEvent> { cont in
            continuation = cont
        }
        self.eventContinuation = continuation
    }

    // MARK: - AgentOrchestrating Implementation

    // swiftlint:disable:next async_without_await
    public func load(chatId: UUID) async throws {
        recordCall("load")
        loadCalls.append((chatId: chatId, timestamp: Date()))

        if let error = shouldThrowOnLoad {
            throw error
        }

        currentChatId = chatId
        isLoaded = true
    }

    // swiftlint:disable:next async_without_await
    public func unload() async throws {
        recordCall("unload")
        unloadCalls.append(Date())

        if let error = shouldThrowOnUnload {
            throw error
        }

        currentChatId = nil
        isLoaded = false
        isGenerating = false
    }

    public func generate(prompt: String, action: Action) async throws {
        recordCall("generate")
        generateCalls.append((prompt: prompt, action: action, timestamp: Date()))

        if let error = shouldThrowOnGenerate {
            throw error
        }

        let runId = UUID()
        eventContinuation?.yield(.generationStarted(runId: runId))
        isGenerating = true

        if generateDelay > 0 {
            try await Task.sleep(nanoseconds: UInt64(generateDelay * 1_000_000_000))
        }

        isGenerating = false
        eventContinuation?.yield(.generationCompleted(runId: runId, totalDurationMs: 0))
    }

    // swiftlint:disable:next async_without_await
    public func stop() async throws {
        recordCall("stop")
        stopCalls.append(Date())

        if let error = shouldThrowOnStop {
            throw error
        }

        isGenerating = false
    }

    // swiftlint:disable:next async_without_await
    public func steer(mode: SteeringMode) async {
        recordCall("steer")
        steerCalls.append((mode: mode, timestamp: Date()))
        currentSteeringMode = mode
    }

    // MARK: - Helper Methods

    private func recordCall(_ method: String) {
        methodCalls.append(MethodCall(
            method: method,
            timestamp: Date()
        ))
    }

    public func wasCalled(_ method: String) -> Bool {
        methodCalls.contains { $0.method == method }
    }

    public func callCount(for method: String) -> Int {
        methodCalls.filter { $0.method == method }.count
    }

    public func reset() {
        methodCalls = []
        loadCalls = []
        unloadCalls = []
        generateCalls = []
        stopCalls = []
        steerCalls = []
        currentChatId = nil
        isLoaded = false
        isGenerating = false
        currentSteeringMode = .inactive
        shouldThrowOnLoad = nil
        shouldThrowOnUnload = nil
        shouldThrowOnGenerate = nil
        shouldThrowOnStop = nil
        generateDelay = 0

        // Reset event stream
        eventContinuation?.finish()
        var continuation: AsyncStream<AgentEvent>.Continuation?
        _eventStream = AsyncStream<AgentEvent> { cont in
            continuation = cont
        }
        eventContinuation = continuation
    }

    /// Emit an event for testing purposes
    public func emitEvent(_ event: AgentEvent) {
        eventContinuation?.yield(event)
    }

    /// Finish the event stream
    public func finishEventStream() {
        eventContinuation?.finish()
    }

    // MARK: - Test Verification Helpers

    public func verifyLoadCalled(with chatId: UUID) -> Bool {
        loadCalls.contains { $0.chatId == chatId }
    }

    public func verifyGenerateCalled(with prompt: String) -> Bool {
        generateCalls.contains { $0.prompt == prompt }
    }

    public func lastGenerateCall() -> (prompt: String, action: Action)? {
        guard let last = generateCalls.last else {
            return nil
        }
        return (last.prompt, last.action)
    }
}
