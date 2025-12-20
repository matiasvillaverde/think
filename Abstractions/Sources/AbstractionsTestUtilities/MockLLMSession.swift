import Abstractions
import Foundation
import Testing

/// Mock implementation of LLMSession for testing
public actor MockLLMSession: LLMSession {
    // MARK: - Nested Types

    /// Thread-safe stop flag for testing
    private final class MockStopFlag: @unchecked Sendable {
        private var stopCalls: [Date] = []
        private let lock = NSLock()

        func recordStop() {
            lock.lock()
            defer { lock.unlock() }
            stopCalls.append(Date())
        }

        func getStopCalls() -> [Date] {
            lock.lock()
            defer { lock.unlock() }
            return stopCalls
        }

        func reset() {
            lock.lock()
            defer { lock.unlock() }
            stopCalls.removeAll()
        }
    }
    /// Tracks all method calls
    public struct MethodCall: Equatable, Sendable {
        public let method: String
        public let parameters: [String: String]
        public let timestamp: Date

        public init(method: String, parameters: [String: String] = [:]) {
            self.method = method
            self.parameters = parameters
            self.timestamp = Date()
        }

        public static func == (lhs: MethodCall, rhs: MethodCall) -> Bool {
            lhs.method == rhs.method && lhs.parameters == rhs.parameters
        }
    }

    /// Mock response for stream method
    public struct MockStreamResponse: Sendable {
        public let chunks: [LLMStreamChunk]
        public let error: Error?
        public let delayBetweenChunks: TimeInterval

        public init(
            chunks: [LLMStreamChunk] = [],
            error: Error? = nil,
            delayBetweenChunks: TimeInterval = 0.01
        ) {
            self.chunks = chunks
            self.error = error
            self.delayBetweenChunks = delayBetweenChunks
        }

        /// Create a response with text chunks
        public static func text(
            _ texts: [String],
            delayBetweenChunks: TimeInterval = 0.01
        ) -> MockStreamResponse {
            let chunks = texts.map { text in
                LLMStreamChunk(
                    text: text,
                    event: .text,
                    metrics: nil
                )
            }
            return MockStreamResponse(
                chunks: chunks,
                delayBetweenChunks: delayBetweenChunks
            )
        }

        /// Create an error response
        public static func error(_ error: Error) -> MockStreamResponse {
            MockStreamResponse(chunks: [], error: error)
        }
    }

    /// Mock response for preload method
    public struct MockPreloadResponse: Sendable {
        public let progress: [Progress]
        public let error: Error?
        public let delayBetweenProgress: TimeInterval

        public init(
            progress: [Progress] = [],
            error: Error? = nil,
            delayBetweenProgress: TimeInterval = 0.01
        ) {
            self.progress = progress
            self.error = error
            self.delayBetweenProgress = delayBetweenProgress
        }

        /// Create a standard loading response
        public static func loading(steps: Int = 5) -> MockPreloadResponse {
            var progressItems: [Progress] = []
            for i in 1...steps {
                let progress = Progress(totalUnitCount: Int64(steps))
                progress.completedUnitCount = Int64(i)
                progress.localizedDescription = "Loading model..."
                progress.localizedAdditionalDescription = "Step \(i) of \(steps)"
                progressItems.append(progress)
            }
            return MockPreloadResponse(progress: progressItems)
        }

        /// Create an already loaded response
        public static func alreadyLoaded() -> MockPreloadResponse {
            let progress = Progress(totalUnitCount: 1)
            progress.completedUnitCount = 1
            progress.localizedDescription = "Model already loaded"
            return MockPreloadResponse(progress: [progress])
        }
    }

    // MARK: - State

    public private(set) var calls: [MethodCall] = []
    public private(set) var streamCalls: [(input: LLMInput, timestamp: Date)] = []
    public private(set) var stopCalls: [Date] = []
    public private(set) var preloadCalls: [(
        configuration: ProviderConfiguration,
        timestamp: Date
    )] = []
    public private(set) var unloadCalls: [Date] = []

    private var isGenerating: Bool = false
    private var isLoaded: Bool = false
    private var shouldStop: Bool = false
    private let stopFlag = MockStopFlag()

    // MARK: - Configurable Responses

    public var streamResponse: MockStreamResponse = .text(["Mock response"])
    public var sequentialStreamResponses: [MockStreamResponse] = []
    private var streamCallCount: Int = 0
    public var preloadResponse: MockPreloadResponse = .alreadyLoaded()
    public var stopError: Error?

    // MARK: - Initialization

    public init() {
        // Empty initializer for actor
    }

    // MARK: - LLMSession Protocol

    public func stream(_ input: LLMInput) -> AsyncThrowingStream<LLMStreamChunk, Error> {
        let call = MethodCall(
            method: "stream",
            parameters: [
                "context": String(input.context.prefix(100)),
                "maxTokens": String(input.limits.maxTokens),
                "temperature": String(input.sampling.temperature)
            ]
        )
        calls.append(call)
        streamCalls.append((input: input, timestamp: Date()))

        // Use sequential responses if configured, otherwise use single response
        let response: MockStreamResponse
        if !sequentialStreamResponses.isEmpty {
            let index = min(streamCallCount, sequentialStreamResponses.count - 1)
            response = sequentialStreamResponses[index]
            streamCallCount += 1
        } else {
            response = streamResponse
        }

        shouldStop = false
        isGenerating = true

        return AsyncThrowingStream { continuation in
            Task {
                await self.performStream(response: response, continuation: continuation)
            }
        }
    }

    nonisolated public func stop() {
        stopFlag.recordStop()
        Task { @MainActor in
            await self.recordStopCall()
        }
    }

    private func recordStopCall() {
        let call = MethodCall(method: "stop")
        calls.append(call)
        stopCalls.append(Date())
    }

    /// Get stop calls for testing - merges with legacy stopCalls
    public func getAllStopCalls() -> [Date] {
        let flagCalls = stopFlag.getStopCalls()
        return stopCalls + flagCalls
    }

    public func preload(
        configuration: ProviderConfiguration
    ) -> AsyncThrowingStream<Progress, Error> {
        let call = MethodCall(
            method: "preload",
            parameters: [
                "location": configuration.location.absoluteString,
                "modelName": configuration.modelName
            ]
        )
        calls.append(call)
        preloadCalls.append((configuration: configuration, timestamp: Date()))

        let response = preloadResponse

        return AsyncThrowingStream { continuation in
            Task {
                await self.performPreload(response: response, continuation: continuation)
            }
        }
    }

    public func unload() {
        let call = MethodCall(method: "unload")
        calls.append(call)
        unloadCalls.append(Date())

        isLoaded = false
        isGenerating = false
        shouldStop = false
    }

    // MARK: - Helper Methods

    private func setLoaded(_ value: Bool) {
        isLoaded = value
    }

    private func performStream(
        response: MockStreamResponse,
        continuation: AsyncThrowingStream<LLMStreamChunk, Error>.Continuation
    ) async {
        defer {
            self.isGenerating = false
        }

        if let error = response.error {
            continuation.finish(throwing: error)
            return
        }

        for chunk in response.chunks {
            if self.shouldStop {
                continuation.finish(
                    throwing: LLMError.providerError(
                        code: "CANCELLED",
                        message: "Stream was cancelled"
                    )
                )
                return
            }

            if response.delayBetweenChunks > 0 {
                do {
                    let nanos = UInt64(response.delayBetweenChunks * 1_000_000_000)
                    try await Task.sleep(nanoseconds: nanos)
                } catch {
                    continuation.finish(throwing: error)
                    return
                }
            }

            continuation.yield(chunk)
        }

        continuation.finish()
    }

    private func performPreload(
        response: MockPreloadResponse,
        continuation: AsyncThrowingStream<Progress, Error>.Continuation
    ) async {
        if let error = response.error {
            continuation.finish(throwing: error)
            return
        }

        for progress in response.progress {
            if response.delayBetweenProgress > 0 {
                do {
                    let nanos = UInt64(response.delayBetweenProgress * 1_000_000_000)
                    try await Task.sleep(nanoseconds: nanos)
                } catch {
                    continuation.finish(throwing: error)
                    return
                }
            }
            continuation.yield(progress)
        }

        self.setLoaded(true)
        continuation.finish()
    }

    // MARK: - Verification Helpers

    /// Verify that stream was called with specific input
    public func verifyStreamCalled(
        with context: String? = nil,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        #expect(!streamCalls.isEmpty, "Expected stream to be called")

        if let expectedContext = context {
            let matchFound = streamCalls.contains { call in
                call.input.context.contains(expectedContext)
            }
            let message = "Expected stream to be called with context containing: \(expectedContext)"
            #expect(matchFound, Comment(rawValue: message))
        }
    }

    /// Verify that preload was called with specific configuration
    public func verifyPreloadCalled(
        with modelName: String? = nil,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        #expect(!preloadCalls.isEmpty, "Expected preload to be called")

        if let expectedModelName = modelName {
            let matchFound = preloadCalls.contains { call in
                call.configuration.modelName == expectedModelName
            }
            let message = "Expected preload to be called with model: \(expectedModelName)"
            #expect(matchFound, Comment(rawValue: message))
        }
    }

    /// Verify that stop was called
    public func verifyStopCalled(
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        #expect(!getAllStopCalls().isEmpty, "Expected stop to be called")
    }

    /// Verify that unload was called
    public func verifyUnloadCalled(
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        #expect(!unloadCalls.isEmpty, "Expected unload to be called")
    }

    /// Verify a specific method was called
    public func verifyMethodCalled(
        _ method: String,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let methodCalled = calls.contains { $0.method == method }
        #expect(methodCalled, "Expected \(method) to be called")
    }

    /// Verify no methods were called
    public func verifyNoMethodsCalled(
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let message = "Expected no methods to be called, but found: \(calls.map(\.method))"
        #expect(calls.isEmpty, Comment(rawValue: message))
    }

    /// Get the number of times a method was called
    public func callCount(for method: String) -> Int {
        calls.filter { $0.method == method }.count
    }

    /// Get the last stream input
    public var lastStreamInput: LLMInput? {
        streamCalls.last?.input
    }

    /// Get the last preload configuration
    public var lastPreloadConfiguration: ProviderConfiguration? {
        preloadCalls.last?.configuration
    }

    /// Check if currently generating
    public var isCurrentlyGenerating: Bool {
        isGenerating
    }

    /// Check if model is loaded
    public var isModelLoaded: Bool {
        isLoaded
    }

    /// Reset all state
    public func reset() {
        calls.removeAll()
        streamCalls.removeAll()
        stopCalls.removeAll()
        preloadCalls.removeAll()
        unloadCalls.removeAll()

        isGenerating = false
        isLoaded = false
        shouldStop = false
        streamCallCount = 0

        streamResponse = .text(["Mock response"])
        sequentialStreamResponses = []
        preloadResponse = .alreadyLoaded()
        stopError = nil
    }
}

// MARK: - Convenience Extensions

extension MockLLMSession {
    /// Configure to simulate a successful text generation
    public func configureForSuccessfulGeneration(
        texts: [String],
        delay: TimeInterval = 0.01
    ) {
        streamResponse = .text(texts, delayBetweenChunks: delay)
    }

    /// Configure to simulate a generation error
    public func configureForGenerationError(_ error: Error) {
        streamResponse = .error(error)
    }

    /// Configure to simulate successful model loading
    public func configureForSuccessfulPreload(
        steps: Int = 5,
        delay: TimeInterval = 0.01
    ) {
        preloadResponse = MockPreloadResponse(
            progress: MockPreloadResponse.loading(steps: steps).progress,
            delayBetweenProgress: delay
        )
    }

    /// Configure to simulate preload error
    public func configureForPreloadError(_ error: Error) {
        preloadResponse = MockPreloadResponse(error: error)
    }

    /// Configure to simulate model already loaded
    public func configureForAlreadyLoaded() {
        preloadResponse = .alreadyLoaded()
        isLoaded = true
    }

    /// Configure sequential stream responses for multiple iterations
    public func setSequentialStreamResponses(_ responses: [MockStreamResponse]) {
        sequentialStreamResponses = responses
        streamCallCount = 0
    }
}
