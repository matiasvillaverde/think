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

    // MARK: - Method-Specific Call Tracking

    public private(set) var loadCalls: [(chatId: UUID, timestamp: Date)] = []
    public private(set) var unloadCalls: [Date] = []
    public private(set) var generateCalls: [(prompt: String, action: Action, timestamp: Date)] = []
    public private(set) var stopCalls: [Date] = []

    // MARK: - Mock Configuration

    public var shouldThrowOnLoad: Error?
    public var shouldThrowOnUnload: Error?
    public var shouldThrowOnGenerate: Error?
    public var shouldThrowOnStop: Error?

    public var generateDelay: TimeInterval = 0

    // MARK: - Initialization

    public init() {
        // Empty initializer
    }

    // MARK: - AgentOrchestrating Implementation

    public func load(chatId: UUID) throws {
        recordCall("load")
        loadCalls.append((chatId: chatId, timestamp: Date()))

        if let error = shouldThrowOnLoad {
            throw error
        }

        currentChatId = chatId
        isLoaded = true
    }

    public func unload() throws {
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

        isGenerating = true

        if generateDelay > 0 {
            try await Task.sleep(nanoseconds: UInt64(generateDelay * 1_000_000_000))
        }

        isGenerating = false
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
        currentChatId = nil
        isLoaded = false
        isGenerating = false
        shouldThrowOnLoad = nil
        shouldThrowOnUnload = nil
        shouldThrowOnGenerate = nil
        shouldThrowOnStop = nil
        generateDelay = 0
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
