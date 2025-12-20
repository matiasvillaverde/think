import Foundation
@testable import ModelDownloader
import Testing

@Suite("DownloadTaskManager Tests")
struct DownloadTaskManagerTests {
    @Test("Stores and retrieves download tasks")
    func testStoreAndRetrieveTask() async {
        // Given
        let manager: DownloadTaskManager = DownloadTaskManager()
        let repositoryId: String = "test/model"
        let task: Task<Void, Never> = Task<Void, Never> {
            try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
        }

        // When
        await manager.store(task: task, for: repositoryId)
        let retrievedTask: Task<Void, Never>? = await manager.getTask(for: repositoryId)

        // Then
        #expect(retrievedTask != nil)

        // Cleanup
        task.cancel()
    }

    @Test("Returns nil for non-existent task")
    func testReturnsNilForNonExistentTask() async {
        // Given
        let manager: DownloadTaskManager = DownloadTaskManager()
        let repositoryId: String = "test/model"

        // When
        let task: Task<Void, Never>? = await manager.getTask(for: repositoryId)

        // Then
        #expect(task == nil)
    }

    @Test("Cancels and removes task")
    func testCancelAndRemoveTask() async {
        // Given
        let manager: DownloadTaskManager = DownloadTaskManager()
        let repositoryId: String = "test/model"
        let cancellationState: CancellationState = CancellationState()

        let task: Task<Void, Never> = Task<Void, Never> {
            do {
                try await Task.sleep(nanoseconds: 10_000_000_000) // 10 seconds
            } catch {
                // Task was cancelled
                await cancellationState.markCancelled()
            }
        }

        await manager.store(task: task, for: repositoryId)

        // When
        let wasCancelled: Bool = await manager.cancel(repositoryId: repositoryId)

        // Then
        #expect(wasCancelled == true)

        // Verify task was removed
        let retrievedTask: Task<Void, Never>? = await manager.getTask(for: repositoryId)
        #expect(retrievedTask == nil)

        // Give time for the task to register cancellation
        try? await Task.sleep(nanoseconds: 100_000_000) // 100ms
        #expect(await cancellationState.wasCancelled == true)
    }

    @Test("Cancel returns false for non-existent task")
    func testCancelNonExistentTask() async {
        // Given
        let manager: DownloadTaskManager = DownloadTaskManager()
        let repositoryId: String = "test/model"

        // When
        let wasCancelled: Bool = await manager.cancel(repositoryId: repositoryId)

        // Then
        #expect(wasCancelled == false)
    }

    @Test("Cancels all tasks")
    func testCancelAllTasks() async {
        // Given
        let manager: DownloadTaskManager = DownloadTaskManager()
        let repositoryIds: [String] = ["test/model1", "test/model2", "test/model3"]
        var storedTasks: [Task<Void, Never>] = []

        for repositoryId: String in repositoryIds {
            let task: Task<Void, Never> = Task<Void, Never> { @Sendable in
                do {
                    try await Task.sleep(nanoseconds: 10_000_000_000)
                } catch {
                    // Task was cancelled
                }
            }
            await manager.store(task: task, for: repositoryId)
            storedTasks.append(task)
        }

        // When
        await manager.cancelAll()

        // Then - give tasks a moment to process cancellation
        try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds

        // Check if tasks were cancelled
        var cancelledCount: Int = 0
        for task: Task<Void, Never> in storedTasks where task.isCancelled {
            cancelledCount += 1
        }
        #expect(cancelledCount == 3)

        // Verify all tasks were removed
        for repositoryId: String in repositoryIds {
            let task: Task<Void, Never>? = await manager.getTask(for: repositoryId)
            #expect(task == nil)
        }
    }

    @Test("Removes task from tracking")
    func testRemoveTask() async {
        // Given
        let manager: DownloadTaskManager = DownloadTaskManager()
        let repositoryId: String = "test/model"

        let task: Task<Void, Never> = Task<Void, Never> {
            try? await Task.sleep(nanoseconds: 10_000_000_000)
        }

        await manager.store(task: task, for: repositoryId)

        // When
        await manager.remove(repositoryId: repositoryId)

        // Then
        let retrievedTask: Task<Void, Never>? = await manager.getTask(for: repositoryId)
        #expect(retrievedTask == nil)

        // Cleanup - task should still be running
        task.cancel()
    }

    @Test("Gets all active repository IDs")
    func testGetAllActiveRepositoryIds() async {
        // Given
        let manager: DownloadTaskManager = DownloadTaskManager()
        let repositoryIds: Set<String> = Set(["test/model1", "test/model2", "test/model3"])

        for repositoryId: String in repositoryIds {
            let task: Task<Void, Never> = Task<Void, Never> {
                try? await Task.sleep(nanoseconds: 10_000_000_000)
            }
            await manager.store(task: task, for: repositoryId)
        }

        // When
        let activeIds: [String] = await manager.getActiveRepositoryIds()

        // Then
        #expect(Set(activeIds) == repositoryIds)

        // Cleanup
        await manager.cancelAll()
    }

    @Test("Replaces existing task for same repository ID")
    func testReplacesExistingTask() async {
        // Given
        let manager: DownloadTaskManager = DownloadTaskManager()
        let repositoryId: String = "test/model"
        let cancellationState: CancellationState = CancellationState()

        let firstTask: Task<Void, Never> = Task<Void, Never> {
            do {
                try await Task.sleep(nanoseconds: 10_000_000_000)
            } catch {
                await cancellationState.markCancelled()
            }
        }

        await manager.store(task: firstTask, for: repositoryId)

        // When - Store a new task with same ID
        let secondTask: Task<Void, Never> = Task<Void, Never> {
            try? await Task.sleep(nanoseconds: 10_000_000_000)
        }
        await manager.store(task: secondTask, for: repositoryId)

        // Give first task time to process cancellation
        try? await Task.sleep(nanoseconds: 100_000_000) // 100ms

        // Then
        #expect(await cancellationState.wasCancelled == true)

        let retrievedTask: Task<Void, Never>? = await manager.getTask(for: repositoryId)
        #expect(retrievedTask != nil)

        // Cleanup
        secondTask.cancel()
    }

    @Test("Checks if download is active")
    func testIsDownloading() async {
        // Given
        let manager: DownloadTaskManager = DownloadTaskManager()
        let repositoryId1: String = "test/model1"
        let repositoryId2: String = "test/model2"

        let task: Task<Void, Never> = Task<Void, Never> {
            try? await Task.sleep(nanoseconds: 10_000_000_000)
        }
        await manager.store(task: task, for: repositoryId1)

        // When/Then
        #expect(await manager.isDownloading(repositoryId: repositoryId1) == true)
        #expect(await manager.isDownloading(repositoryId: repositoryId2) == false)

        // Cleanup
        task.cancel()
    }

    @Test("Gets active download count")
    func testActiveDownloadCount() async {
        // Given
        let manager: DownloadTaskManager = DownloadTaskManager()

        // When/Then - Initially empty
        #expect(await manager.activeDownloadCount() == 0)

        // Add tasks
        let task1: Task<Void, Never> = Task<Void, Never> { try? await Task.sleep(nanoseconds: 10_000_000_000) }
        let task2: Task<Void, Never> = Task<Void, Never> { try? await Task.sleep(nanoseconds: 10_000_000_000) }

        await manager.store(task: task1, for: "test/model1")
        #expect(await manager.activeDownloadCount() == 1)

        await manager.store(task: task2, for: "test/model2")
        #expect(await manager.activeDownloadCount() == 2)

        // Cleanup
        await manager.cancelAll()
        #expect(await manager.activeDownloadCount() == 0)
    }
}

// MARK: - Helper for async expectations
private actor CancellationState {
    private var cancelled: Bool = false

    func markCancelled() {
        cancelled = true
    }

    var wasCancelled: Bool {
        cancelled
    }
}

private actor Expectation {
    private var isFulfilled: Bool = false
    private var continuations: [CheckedContinuation<Void, Never>] = []

    func fulfill() {
        isFulfilled = true
        for continuation: CheckedContinuation<Void, Never> in continuations {
            continuation.resume()
        }
        continuations.removeAll()
    }

    func fulfillment(within timeout: Duration) async {
        if isFulfilled {
            return
        }

        await withTaskGroup(of: Void.self) { group in
            group.addTask {
                await withCheckedContinuation { continuation in
                    Task {
                        await self.addContinuation(continuation)
                    }
                }
            }

            group.addTask {
                try? await Task.sleep(for: timeout)
                await self.timeOut()
            }

            // Wait for first to complete
            await group.next()
            group.cancelAll()
        }
    }

    private func addContinuation(_ continuation: CheckedContinuation<Void, Never>) {
        if isFulfilled {
            continuation.resume()
        } else {
            continuations.append(continuation)
        }
    }

    private func timeOut() {
        for continuation: CheckedContinuation<Void, Never> in continuations {
            continuation.resume()
        }
        continuations.removeAll()
    }
}
