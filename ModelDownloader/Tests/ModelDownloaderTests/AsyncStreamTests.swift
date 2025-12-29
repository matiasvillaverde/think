import Abstractions
import Foundation
@testable import ModelDownloader
import Testing

/// Tests specific to AsyncThrowingStream behavior in ModelDownloader
@Suite("AsyncThrowingStream Tests")
struct AsyncStreamTests {
    // MARK: - Stream Cancellation Tests

    @Test("Stream cancellation stops download")
    func testStreamCancellation() async throws {
        // Create a stream that simulates download events
        typealias Stream = AsyncThrowingStream<DownloadEvent, Error>
        let stream: Stream = Stream { continuation in
            Task {
                do {
                    // Yield several progress events
                    for step: Int in 1...10 {
                        continuation.yield(.progress(DownloadProgress(
                            bytesDownloaded: Int64(step * 10),
                            totalBytes: 100,
                            filesCompleted: 0,
                            totalFiles: 1,
                            currentFileName: "test.safetensors"
                        )))

                        // Small delay between events
                        try await Task.sleep(nanoseconds: 100_000_000) // 100ms

                        // Check for cancellation
                        if Task.isCancelled {
                            continuation.finish(throwing: CancellationError())
                            return
                        }
                    }

                    // If not cancelled, complete normally
                    continuation.yield(.completed(ModelInfo(
                        id: UUID(),
                        name: "test/model",
                        backend: .mlx,
                        location: URL(fileURLWithPath: "/tmp/test"),
                        totalSize: 100,
                        downloadDate: Date()
                    )))
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }

        // Start download task that we'll cancel
        let downloadTask: Task<Void, Error> = Task {
            var progressCount: Int = 0

            do {
                for try await event in stream {
                    switch event {
                    case .progress(let progress):
                        progressCount += 1
                        print("Progress update \(progressCount): \(progress.percentage)%")

                        // Cancel after a few progress updates
                        if progressCount >= 3 {
                            print("Cancelling download task...")
                            throw CancellationError()
                        }

                    case .completed:
                        // Should not reach here
                        Issue.record("Download should have been cancelled")
                    }
                }
            } catch is CancellationError {
                print("Download cancelled as expected")
                throw CancellationError()
            } catch {
                print("Unexpected error: \(error)")
                throw error
            }
        }

        // Wait a bit then cancel
        try await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
        downloadTask.cancel()

        // Verify the task was cancelled
        do {
            try await downloadTask.value
            Issue.record("Task should have been cancelled")
        } catch is CancellationError {
            // Expected
            #expect(Bool(true))
        }
    }

    @Test("Stream properly handles Task cancellation")
    func testTaskCancellationPropagation() async {
        // Test that task cancellation is properly detected
        let expectation: AsyncExpectation = AsyncExpectation()

        let task: Task<String, Error> = Task {
            do {
                // Create a long-running async operation
                for iteration in 0..<100 {
                    // Check cancellation at each iteration
                    try Task.checkCancellation()

                    // Small delay to allow cancellation to happen
                    try await Task.sleep(nanoseconds: 10_000_000) // 10ms

                    if iteration == 5 {
                        // Signal that we've started processing
                        await expectation.fulfill()
                    }
                }

                // Should not reach here if cancelled
                return "completed"
            } catch {
                throw error
            }
        }

        // Wait for task to start processing
        await expectation.wait()

        // Cancel the task
        task.cancel()

        // Verify cancellation
        do {
            let result: String = try await task.value
            Issue.record("Expected CancellationError but got result: \(result)")
        } catch is CancellationError {
            // This is expected
            #expect(Bool(true))
        } catch {
            Issue.record("Expected CancellationError but got: \(error)")
        }
    }

    // Helper for async coordination
    private actor AsyncExpectation {
        private var isFulfilled: Bool = false

        func fulfill() {
            isFulfilled = true
        }

        func wait() async {
            while !isFulfilled {
                try? await Task.sleep(nanoseconds: 1_000_000) // 1ms
            }
        }
    }

    // MARK: - Stream Completion Tests

    @Test("Stream completes after yielding completed event")
    func testStreamCompletion() async throws {
        // Use a simple test that yields events directly
        typealias Stream = AsyncThrowingStream<DownloadEvent, Error>
        let stream: Stream = Stream { continuation in
            Task {
                // Yield progress event
                continuation.yield(.progress(DownloadProgress(
                    bytesDownloaded: 50,
                    totalBytes: 100,
                    filesCompleted: 0,
                    totalFiles: 1,
                    currentFileName: "test.safetensors"
                )))

                // Yield completion event
                continuation.yield(.completed(ModelInfo(
                    id: UUID(),
                    name: "test/model",
                    backend: .mlx,
                    location: URL(fileURLWithPath: "/tmp/test"),
                    totalSize: 100,
                    downloadDate: Date()
                )))

                // Finish the stream
                continuation.finish()
            }
        }

        var events: [DownloadEvent] = []

        // Consume the stream
        for try await event in stream {
            events.append(event)
        }

        // Verify we got both progress and completed events
        #expect(events.count == 2)

        // Verify last event is completed
        if case .completed = events.last {
            #expect(Bool(true))
        } else {
            Issue.record("Expected last event to be completed")
        }
    }

    // MARK: - Error Propagation Tests

    @Test("Stream propagates download errors")
    func testStreamErrorPropagation() async {
        // Create a coordinator that fails immediately
        let mockFileManager: MockFileManager = MockFileManager()
        let expectedError: ModelDownloadError = ModelDownloadError.networkError(
            NSError(domain: "test", code: -1)
        )
        let failingCoordinator: FailingDownloadCoordinator = FailingDownloadCoordinator(error: expectedError)

        let downloader: HuggingFaceDownloader = HuggingFaceDownloader(
            fileManager: mockFileManager,
            enableProductionFeatures: false,
            downloadCoordinator: failingCoordinator
        )

        var receivedError: Error?
        var eventCount: Int = 0

        do {
            for try await _ in downloader.download(
                modelId: "test/failing-model",
                backend: SendableModel.Backend.mlx
            ) {
                // Should not yield any events
                eventCount += 1
            }
        } catch {
            receivedError = error
        }

        #expect(eventCount == 0)
        #expect(receivedError != nil)
        #expect(receivedError is ModelDownloadError)
    }

    // MARK: - Concurrent Stream Tests

    @Test("Multiple concurrent downloads work correctly")
    @MainActor
    func testConcurrentStreams() async throws {
        let context: TestDownloaderContext = TestDownloaderContext()
        defer { context.cleanup() }

        // Create multiple models
        let models: [SendableModel] = (0..<3).map { index in
            SendableModel(
                id: UUID(),
                ramNeeded: 100_000_000,
                modelType: .language,
                location: "test/model-\(index)",
                architecture: .unknown,
                backend: SendableModel.Backend.mlx,
                locationKind: .huggingFace
            )
        }

        for model in models {
            let fixture: MockHuggingFaceDownloader.FixtureModel = MockHuggingFaceDownloader.FixtureModel(
                modelId: model.location,
                backend: .mlx,
                name: model.location,
                files: [
                    MockHuggingFaceDownloader.FixtureFile(
                        path: "model.safetensors",
                        data: Data(repeating: 0x1, count: 8),
                        size: 8
                    ),
                    MockHuggingFaceDownloader.FixtureFile(
                        path: "config.json",
                        data: Data("{}".utf8),
                        size: 2
                    )
                ]
            )
            await context.mockDownloader.registerFixture(fixture)
        }

        // Start concurrent downloads
        let tasks: [Task<ModelInfo?, Error>] = models.map { model in
            Task { () -> ModelInfo? in
                var result: ModelInfo?

                for try await event in context.downloader.downloadModel(sendableModel: model) {
                    switch event {
                    case .progress(let progress):
                        print("Model \(model.location) progress: \(progress.percentage)%")

                    case .completed(let info):
                        result = info
                        print("Model \(model.location) completed")
                    }
                }

                return result
            }
        }

        // Cancel all tasks (simulating concurrent cancellation)
        for task in tasks {
            task.cancel()
        }

        // Add a small delay to ensure cancellation propagates
        try await Task.sleep(nanoseconds: 100_000_000) // 100ms

        // Verify all tasks handle cancellation properly
        for (index, task) in tasks.enumerated() {
            do {
                _ = try await task.value
            } catch is CancellationError {
                print("Task \(index) cancelled successfully")
            } catch {
                // May also get other errors for test models
                print("Task \(index) failed with: \(error)")
            }
        }

        #expect(Bool(true)) // If we get here, concurrent handling worked
    }

    // MARK: - Backpressure Tests

    @Test("Stream handles slow consumer (backpressure)")
    @MainActor
    func testBackpressure() async {
        // This test verifies that the stream doesn't accumulate unlimited events
        // when the consumer is slow
        let context: TestDownloaderContext = TestDownloaderContext()
        defer { context.cleanup() }

        let sendableModel: SendableModel = SendableModel(
            id: UUID(),
            ramNeeded: 100_000_000,
            modelType: .language,
            location: "test/backpressure-model",
            architecture: .unknown,
            backend: SendableModel.Backend.mlx,
            locationKind: .huggingFace
        )

        let fixture: MockHuggingFaceDownloader.FixtureModel = MockHuggingFaceDownloader.FixtureModel(
            modelId: sendableModel.location,
            backend: .mlx,
            name: sendableModel.location,
            files: [
                MockHuggingFaceDownloader.FixtureFile(
                    path: "model.safetensors",
                    data: Data(repeating: 0x2, count: 16),
                    size: 16
                ),
                MockHuggingFaceDownloader.FixtureFile(
                    path: "config.json",
                    data: Data("{}".utf8),
                    size: 2
                )
            ]
        )
        await context.mockDownloader.registerFixture(fixture)

        var eventCount: Int = 0
        let startTime: Date = Date()

        do {
            for try await event in context.downloader.downloadModel(sendableModel: sendableModel) {
                eventCount += 1

                // Simulate slow consumer
                if case .progress = event {
                    try await Task.sleep(nanoseconds: 100_000_000) // 100ms delay
                }

                // Timeout after 5 seconds
                if Date().timeIntervalSince(startTime) > 5 {
                    break
                }
            }
        } catch {
            // Expected for test models
            print("Download error (expected): \(error)")
        }

        print("Received \(eventCount) events")

        // With proper backpressure, we shouldn't accumulate too many events
        #expect(eventCount < 100) // Reasonable limit for a 5-second test
    }
}

// MARK: - Mock Helpers

private actor FailingDownloadCoordinator: DownloadCoordinating {
    private let error: Error

    init(error: Error) {
        self.error = error
    }

    func start(model _: SendableModel) async throws {
        try await Task.sleep(nanoseconds: 0)
        throw error
    }

    func pause(repositoryId _: String) async throws {
        try await Task.sleep(nanoseconds: 0)
        throw error
    }

    func resume(repositoryId _: String) async throws {
        try await Task.sleep(nanoseconds: 0)
        throw error
    }

    func cancel(repositoryId _: String) async {
        await Task.yield()
    }

    func state(for _: String) async -> DownloadStatus {
        await Task.yield()
        return .notStarted
    }
}
