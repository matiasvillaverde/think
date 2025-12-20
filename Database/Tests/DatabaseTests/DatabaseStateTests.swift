import Testing
import Foundation
import Abstractions
import SwiftData
@testable import Database
import AbstractionsTestUtilities

@Suite(.tags(.state))
struct DatabaseStateTests {
    let mockRag = MockRagging()
    let userId: PersistentIdentifier = User(
        name: "Matias",
        profilePicture: nil,
        prompts: [],
        chats: [],
        agents: [],
        models: []
    ).persistentModelID

    @Test("Database initializes in partially ready state")
    @MainActor
    func initialState() async {
        let state = DatabaseState()
        var currentStatus: DatabaseStatus?

        let callback: @MainActor @Sendable (DatabaseStatus) -> Void = { status in
            currentStatus = status
        }

        await MainActor.run {
            state.onStatusChange = callback
        }

        #expect(currentStatus == nil, "Initial status should not trigger callback")
    }

    @Test("Database transitions to ready state")
    @MainActor
    func readyStateTransition() async throws {
        let state = DatabaseState()
        var currentStatus: DatabaseStatus?

        let callback: @MainActor @Sendable (DatabaseStatus) -> Void = { status in
            currentStatus = status
        }

        await MainActor.run {
            state.onStatusChange = callback
        }

        try await state.setReady(rag: mockRag, userId: userId)

        // Wait for status change to propagate
        try? await Task.sleep(nanoseconds: 100_000_000)

        #expect(currentStatus == .ready, "Status should be ready")

        let result = try? await state.waitUntilReady()
        #expect(result?.rag as? MockRagging === mockRag)
        #expect(result?.userId == userId)
    }

    @Test("Status change callback is not triggered for same status")
    @MainActor
    func noCallbackForSameStatus() async throws {
        let state = DatabaseState()
        var callbackCount = 0

        let callback: @MainActor @Sendable (DatabaseStatus) -> Void = { _ in
            callbackCount += 1
        }

        await MainActor.run {
            state.onStatusChange = callback
        }

        // Set ready state
        try await state.setReady(rag: mockRag, userId: userId)

        #expect(callbackCount == 1, "Callback should be triggered once")

        // Try setting error after ready
        let error = NSError(domain: "test", code: 1, userInfo: nil)
        await state.setError(error)
        #expect(callbackCount == 2, "Callback should be triggered twice")
    }

    @Test("Concurrent state transitions")
    func concurrentStateTransitions() async throws {
        let state = DatabaseState()
        let error = NSError(domain: "test", code: 1, userInfo: nil)

        // Create tasks for concurrent state transitions
        let readyTask = Task {
            try await state.setReady(rag: mockRag, userId: userId)
        }

        let errorTask = Task {
            await state.setError(error)
        }

        // Wait for both tasks to complete
        _ = await [readyTask.result, errorTask.result]

        // Verify final state
        do {
            _ = try await state.waitUntilReady()
            #expect(Bool(false), "Should be in error state")
        } catch let caughtError {
            #expect(caughtError as NSError == error)
        }
    }

    @Test("Cleanup after state transition")
    func cleanupAfterStateTransition() async throws {
        let state = DatabaseState()

        // Create multiple waiting tasks
        let waitTasks = (0..<5).map { _ in
            Task {
                try await state.waitUntilReady()
            }
        }

        // Set ready state
        try await state.setReady(rag: mockRag, userId: userId)

        // Verify all tasks completed
        for task in waitTasks {
            let result = try await task.value
            #expect(result.rag as? MockRagging === mockRag)
            #expect(result.userId == userId)
        }

        // Verify continuations array is empty (if you can expose this for testing)
        // #expect(state.continuations.isEmpty)
    }
}

@Suite(.tags(.edge))
struct DatabaseStateEdgeCases {
    let mockRag = MockRagging()
    let userId: PersistentIdentifier = User(
        name: "Matias",
        profilePicture: nil,
        prompts: [],
        chats: [],
        agents: [],
        models: []
    ).persistentModelID

    @Test("Database handles error state correctly")
    func errorStateHandling() async {
        let state = DatabaseState()
        let testError = NSError(domain: "test", code: 1, userInfo: nil)

        let callback: @MainActor @Sendable (DatabaseStatus) -> Void = { status in
            if case .failed(let error) = status {
                #expect((error as NSError) == testError)
            } else {
                #expect(Bool(false), "Status should be failed")
            }
        }

        await MainActor.run {
            state.onStatusChange = callback
        }

        await state.setError(testError)
    }

    @Test("Multiple ready state transitions are not allowed")
    @MainActor
    func multipleReadyTransitions() async throws {
        let state = DatabaseState()
        var currentStatus: DatabaseStatus?
        let callback: @MainActor @Sendable (DatabaseStatus) -> Void = { status in
            currentStatus = status
        }
        await MainActor.run {
            state.onStatusChange = callback
        }
        try await state.setReady(rag: mockRag, userId: userId)
        _ = try await state.waitUntilReady()
        #expect(currentStatus == .ready)
        await #expect(throws: DatabaseError.invalidStateTransition) {
            try await state.setReady(rag: mockRag, userId: userId)
        }
    }
}

@Suite(.tags(.performance))
struct DatabaseStatePerformanceTests {
    let mockRag = MockRagging()
    let userId: PersistentIdentifier = User(
        name: "Matias",
        profilePicture: nil,
        prompts: [],
        chats: [],
        agents: [],
        models: []
    ).persistentModelID

    @Test("Wait until ready performance", arguments: [10, 100, 1000])
    func waitUntilReadyPerformance(continuationCount: Int) async throws {
        let state = DatabaseState()

        // Create multiple waitUntilReady tasks
        let tasks = (0..<continuationCount).map { _ in
            Task {
                try await state.waitUntilReady()
            }
        }

        // Simulate some work
        try await Task.sleep(nanoseconds: 100_000_000)

        // Set ready state
        try await state.setReady(rag: mockRag, userId: userId)

        // Verify all tasks complete successfully
        for task in tasks {
            let (rag, id) = try await task.value
            #expect(rag as? MockRagging === mockRag)
            #expect(id == userId)
        }
    }
}

@Suite(.tags(.acceptance))
struct DatabaseStateAcceptanceTests {
    let mockRag = MockRagging()
    let userId: PersistentIdentifier = User(
        name: "Matias",
        profilePicture: nil,
        prompts: [],
        chats: [],
        agents: [],
        models: []
    ).persistentModelID

    @Test("Complete database initialization flow")
    @MainActor
    func completeInitializationFlow() async throws {
        let state = DatabaseState()
        var statusChanges: [DatabaseStatus] = []

        let callback: @MainActor @Sendable (DatabaseStatus) -> Void = { status in
            statusChanges.append(status)
        }

        await MainActor.run {
            state.onStatusChange = callback
        }

        // Start waiting for ready state
        let waitTask = Task {
            try await state.waitUntilReady()
        }

        // Simulate initialization delay
        try await Task.sleep(nanoseconds: 500_000_000)

        // Set ready state
        try await state.setReady(rag: mockRag, userId: userId)

        let (rag, id) = try await waitTask.value

        #expect(rag as? MockRagging === mockRag)
        #expect(id == userId)
        #expect(statusChanges.count == 1)
        #expect(statusChanges.first == .ready)
    }

    @Test("Error handling in initialization flow")
    @MainActor
    func errorHandlingFlow() async {
        let state = DatabaseState()
        let testError = NSError(domain: "test", code: 1, userInfo: nil)
        var statusChanges: [DatabaseStatus] = []

        let callback: @MainActor @Sendable (DatabaseStatus) -> Void = { status in
            statusChanges.append(status)
        }

        await MainActor.run {
            state.onStatusChange = callback
        }

        // Start waiting for ready state
        let waitTask = Task {
            try await state.waitUntilReady()
        }

        // Set error state
        await state.setError(testError)

        do {
            _ = try await waitTask.value
            #expect(Bool(false), "waitUntilReady should throw an error")
        } catch {
            #expect((error as NSError) == testError)
        }

        #expect(statusChanges.count == 1)
        if case .failed(let error) = statusChanges.first {
            #expect(error == testError)
        } else {
            #expect(Bool(false), "Status should be failed")
        }
    }
}
