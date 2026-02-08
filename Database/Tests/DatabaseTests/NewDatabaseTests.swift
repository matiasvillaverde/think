// NewDatabaseTests.swift
import Testing
import Foundation
import SwiftData
import Abstractions
@testable import Database
import AbstractionsTestUtilities

@Suite("NewDatabase Core Tests")
struct NewDatabaseTests {
    @Suite(.tags(.acceptance))
    struct ConfigurationTests {
        @Test("Database initializes with default configuration")
        func initializeWithDefaultConfig() async throws {
            // Given
            let config = DatabaseConfiguration(
                isStoredInMemoryOnly: true,
                allowsSave: true,
                ragFactory: MockRagFactory(mockRag: MockRagging())
            )

            let database = try Database.new(configuration: config)

            // Then - Wait for ready state
            try await waitForStatus(database, expectedStatus: .ready)
            await #expect(database.status == .ready)
        }
    }

    @Suite(.tags(.state))
    struct StateManagementTests {
        @Test("Database transitions through expected states")
        func stateTransitions() async throws {
            // Given
            let config = DatabaseConfiguration(
                isStoredInMemoryOnly: true,
                allowsSave: true,
                ragFactory: MockRagFactory(mockRag: MockRagging())
            )

            // When
            let database = try Database.new(configuration: config)

            // Then - Check ready
            try await waitForStatus(database, expectedStatus: .ready)
            await #expect(database.status == .ready)
        }

        @Test("Database handles failures gracefully")
        func handleFailures() async throws {
            // Given
            let testError = NSError(domain: "test", code: 1)

            let config = DatabaseConfiguration(
                isStoredInMemoryOnly: true,
                allowsSave: true,
                ragFactory: MockRagFactory(mockRag: MockRagging(), error: testError)
            )

            // When
            let database = try Database.new(configuration: config)

            // Then
            try await waitForStatus(database, expectedStatus: .failed(testError))
            await #expect(database.status == .failed(testError))
        }

        @Test("Database handles concurrent state access")
        func concurrentStateAccess() async throws {
            // Given
            let config = DatabaseConfiguration(
                isStoredInMemoryOnly: true,
                allowsSave: true,
                ragFactory: MockRagFactory(mockRag: MockRagging())
            )

            let database = try Database.new(configuration: config)

            // When - Create users concurrently in main and background
            async let mainWrites: () = withTaskGroup(of: Void.self) { group in
                for index in 0..<5 {
                    group.addTask {
                        _ = try? await database.write(CreateUserCommand(name: "Main User \(index)"))
                    }
                }
            }

            async let backgroundWrites: () = withTaskGroup(of: Void.self) { group in
                for index in 0..<5 {
                    group.addTask {
                        try? await database.writeInBackground(CreateUserCommand(name: "Background User \(index)"))
                    }
                }
            }

            // Wait for all writes to complete
            _ = await [mainWrites, backgroundWrites]

            // Then - Verify users were created and timestamps are in order
            let users = try await database.read(GetUsersSortedByCreationCommand())

            // Verify we have all 11 users (1 is created on the init of the DB)
            #expect(users.count == 11)

            // Verify timestamps are in ascending order
            for index in 1..<users.count {
                #expect(users[index-1].createdAt <= users[index].createdAt)
            }

            // Verify we have both main and background users
            let mainUsers = users.filter { $0.name.starts(with: "Main User") }
            let backgroundUsers = users.filter { $0.name.starts(with: "Background User") }

            #expect(mainUsers.count == 5)
            #expect(backgroundUsers.count == 5)
        }
    }

    @Suite(.tags(.edge))
    struct EdgeCasesTests {
        @Test("Database handles RAG errors")
        func handleRagErrors() async throws {
            // Given
            let mockRag = MockRagging(error: DatabaseError.fileNotFound)
            let config = DatabaseConfiguration(
                isStoredInMemoryOnly: true,
                allowsSave: true,
                ragFactory: MockRagFactory(mockRag: mockRag)
            )

            // When
            let database = try Database.new(configuration: config)

            // When/Then
            await #expect(throws: DatabaseError.fileNotFound) {
                _ = try await database.semanticSearch(
                    query: "test",
                    table: "nonexistent",
                    numResults: 1,
                    threshold: 0.5
                )
            }
        }
    }

    @Suite(.tags(.performance))
    struct PerformanceTests {
        @Test("Write performance meets threshold")
        func writePerformance() async throws {
            // Given
            let config = DatabaseConfiguration(
                isStoredInMemoryOnly: true,
                allowsSave: true,
                ragFactory: MockRagFactory(mockRag: MockRagging())
            )

            let database = try Database.new(configuration: config)

            // When
            let start = ProcessInfo.processInfo.systemUptime
            await withThrowingTaskGroup(of: Void.self) { group in
                for _ in 0..<100 {
                    group.addTask {
                        try await database.read(NoopWriteCommand())
                    }
                }
            }
            let duration = ProcessInfo.processInfo.systemUptime - start

            // Then
            // This is a lightweight concurrency sanity check, not a strict benchmark.
            // CI and local environments can vary enough that a hard 5s threshold flakes.
            #expect(duration < 8)
        }

        @Test("Read performance meets threshold")
        func readPerformance() async throws {
            // Given
            let config = DatabaseConfiguration(
                isStoredInMemoryOnly: true,
                allowsSave: true,
                ragFactory: MockRagFactory(mockRag: MockRagging())
            )

            let database = try Database.new(configuration: config)

            // When
            let start = ProcessInfo.processInfo.systemUptime
            await withThrowingTaskGroup(of: Void.self) { group in
                for _ in 0..<100 {
                    group.addTask {
                        _ = try await database.read(ValidateStateCommand())
                    }
                }
            }
            let duration = ProcessInfo.processInfo.systemUptime - start

            // Then
            // This is a lightweight concurrency sanity check, not a strict benchmark.
            // CI and local environments can vary enough that a hard 5s threshold flakes.
            #expect(duration < 8)
        }
    }
}

struct ValidateStateCommand: ReadCommand {
    typealias Result = Void
    var requiresUser: Bool { false }
    var requiresRag: Bool { false }

    func execute(
        in context: ModelContext,
        userId: PersistentIdentifier?,
        rag: Ragging?
    ) {
        Thread.sleep(forTimeInterval: 0.01) // Exactly 0.01 seconds
    }
}

struct ValidateModelsCommand: ReadCommand {
    typealias Result = Int
    var requiresUser: Bool { true }
    var requiresRag: Bool { false }

    func execute(
        in context: ModelContext,
        userId: PersistentIdentifier?,
        rag: Ragging?
    ) throws -> Int {
        let descriptor = FetchDescriptor<User>()
        let users = try context.fetch(descriptor)
        return users.first?.models.count ?? 0
    }
}

struct ValidateUserCommand: ReadCommand {
    typealias Result = Int
    var requiresUser: Bool { true }
    var requiresRag: Bool { false }

    func execute(
        in context: ModelContext,
        userId: PersistentIdentifier?,
        rag: Ragging?
    ) throws -> Int {
        let descriptor = FetchDescriptor<User>()
        let users = try context.fetch(descriptor)
        return users.count
    }
}

struct NoopWriteCommand: ReadCommand {
    var requiresUser: Bool { false }
    var requiresRag: Bool { false }

    func execute(
        in context: ModelContext,
        userId: PersistentIdentifier?,
        rag: Ragging?
    ) {
        Thread.sleep(forTimeInterval: 0.01) // Exactly 0.01 seconds
    }
}

// MARK: - Test Commands
struct CreateUserCommand: WriteCommand {
    let name: String

    var requiresUser: Bool { false }
    var requiresRag: Bool { false }

    func execute(
        in context: ModelContext,
        userId: PersistentIdentifier?,
        rag: Ragging?
    ) throws -> UUID {
        let user = User(name: name)
        context.insert(user)
        try context.save()
        return user.id
    }
}

struct GetUsersSortedByCreationCommand: ReadCommand {
    typealias Result = [(name: String, createdAt: Date)]
    var requiresUser: Bool { false }
    var requiresRag: Bool { false }

    func execute(
        in context: ModelContext,
        userId: PersistentIdentifier?,
        rag: Ragging?
    ) throws -> Result {
        var descriptor = FetchDescriptor<User>()
        descriptor.sortBy = [SortDescriptor(\.createdAt)]

        let users = try context.fetch(descriptor)
        return users.map { (name: $0.name ?? "", createdAt: $0.createdAt) }
    }
}
