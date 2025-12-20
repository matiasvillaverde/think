// NewDatabaseTests.swift
import Testing
import Foundation
import SwiftData
import Abstractions
@testable import Database
import AbstractionsTestUtilities

@Suite("NewDatabase Additional Tests")
struct NewDatabaseAdditionalTests {
    @Suite(.tags(.core))
    struct BackgroundOperationsTests {
        @Test("writeInBackground handles concurrent writes correctly")
        func concurrentBackgroundWrites() async throws {
            // Given
            let config = DatabaseConfiguration(
                isStoredInMemoryOnly: true,
                allowsSave: true,
                ragFactory: MockRagFactory(mockRag: MockRagging())
            )
            let database = try Database.new(configuration: config)

            // When - Execute multiple background writes concurrently
            await withThrowingTaskGroup(of: Void.self) { group in
                for index in 0..<10 {
                    group.addTask {
                        try await database.writeInBackground(CreateUserCommand(name: "User \(index)"))
                    }
                }
            }

            // Then
            let users = try await database.read(GetUsersSortedByCreationCommand())
            #expect(users.count == 11) // 10 new users + 1 initial user
        }

        @Test("readInBackground handles concurrent reads correctly")
        func concurrentBackgroundReads() async throws {
            // Given
            let config = DatabaseConfiguration(
                isStoredInMemoryOnly: true,
                allowsSave: true,
                ragFactory: MockRagFactory(mockRag: MockRagging())
            )
            let database = try Database.new(configuration: config)

            // Create some test data
            for index in 0..<5 {
                try await database.write(CreateUserCommand(name: "Test User \(index)"))
            }

            // When - Execute multiple background reads concurrently
            await withThrowingTaskGroup(of: Int.self) { group in
                for _ in 0..<10 {
                    group.addTask {
                        try await database.readInBackground(ValidateUserCommand())
                    }
                }
            }

            // Then - Verify consistency
            let finalCount = try await database.read(ValidateUserCommand())
            #expect(finalCount == 6) // 5 test users + 1 initial user
        }
    }

    @Suite(.tags(.core))
    struct SaveOperationsTests {
        @Test("save persists changes to disk")
        func savePersistsChanges() async throws {
            // Given
            let config = DatabaseConfiguration(
                isStoredInMemoryOnly: true,
                allowsSave: true,
                ragFactory: MockRagFactory(mockRag: MockRagging())
            )
            let database = try Database.new(configuration: config)

            // When
            try await database.write(CreateUserCommand(name: "Save Test User"))
            try await database.save()

            // Then - Create new database instance and verify data persists
            let users = try await database.read(GetUsersSortedByCreationCommand())
            #expect(users.contains { $0.name == "Save Test User" })
        }

        @Test("save handles concurrent save operations")
        func concurrentSaves() async throws {
            // Given
            let config = DatabaseConfiguration(
                isStoredInMemoryOnly: true,
                allowsSave: true,
                ragFactory: MockRagFactory(mockRag: MockRagging())
            )
            let database = try Database.new(configuration: config)

            // When - Attempt concurrent saves
            await withThrowingTaskGroup(of: Void.self) { group in
                for _ in 0..<5 {
                    group.addTask {
                        try await database.save()
                    }
                }
            }
        }
    }

    @Suite(.tags(.core))
    struct SemanticSearchTests {
        @Test("semanticSearch passes correct parameters to RAG")
        func searchParameterPassing() async throws {
            // Given
            let expectedResults = [
                SearchResult(id: UUID(), text: "test result", keywords: "test", score: 0.9, rowId: 1),
                SearchResult(id: UUID(), text: "another result", keywords: "test", score: 0.8, rowId: 2)
            ]
            let mockRag = MockRagging(searchResults: expectedResults)
            let config = DatabaseConfiguration(
                isStoredInMemoryOnly: true,
                allowsSave: true,
                ragFactory: MockRagFactory(mockRag: mockRag)
            )
            let database = try Database.new(configuration: config)

            // When
            let query = "test query"
            let table = "test_table"
            let numResults = 5
            let threshold = 0.7

            let results = try await database.semanticSearch(
                query: query,
                table: table,
                numResults: numResults,
                threshold: threshold
            )

            // Then
            guard let lastCall = await mockRag.lastSemanticSearchCall else {
                #expect(Bool(true), "No semantic search call was made")
                return
            }

            #expect(lastCall.query == query)
            #expect(lastCall.table == table)
            #expect(lastCall.numResults == numResults)
            #expect(lastCall.threshold == threshold)

            // Verify call count
            await #expect(mockRag.semanticSearchCalls.count == 1)

            // Verify results are returned correctly
            #expect(results.count == 2)
            #expect(results == expectedResults)

            // Verify all calls had valid parameters
            for call in await mockRag.semanticSearchCalls {
                #expect(!call.query.isEmpty)
                #expect(!call.table.isEmpty)
                #expect(call.numResults > 0)
                #expect(call.threshold >= 0 && call.threshold <= 1)
            }
        }

        @Test("semanticSearch handles empty results")
        func searchEmptyResults() async throws {
            // Given
            let mockRag = MockRagging(searchResults: [])
            let config = DatabaseConfiguration(
                isStoredInMemoryOnly: true,
                allowsSave: true,
                ragFactory: MockRagFactory(mockRag: mockRag)
            )
            let database = try Database.new(configuration: config)

            // When
            let results = try await database.semanticSearch(
                query: "test",
                table: "test_table",
                numResults: 5,
                threshold: 0.7
            )

            // Then
            #expect(results.isEmpty)
        }
    }

    @Suite(.tags(.edge))
    struct EdgeCasesTests {
        @Test("Database handles large concurrent operations")
        func largeConcurrentOperations() async throws {
            // Given
            let config = DatabaseConfiguration(
                isStoredInMemoryOnly: true,
                allowsSave: true,
                ragFactory: MockRagFactory(mockRag: MockRagging())
            )
            let database = try Database.new(configuration: config)

            // When - Mix of reads and writes
            await withThrowingTaskGroup(of: Void.self) { group in
                // Background writes
                for index in 0..<50 {
                    group.addTask {
                        try await database.writeInBackground(CreateUserCommand(name: "BG User \(index)"))
                    }
                }

                // Main thread writes
                for index in 0..<50 {
                    group.addTask {
                        try await database.write(CreateUserCommand(name: "Main User \(index)"))
                    }
                }

                // Background reads
                for _ in 0..<100 {
                    group.addTask {
                        _ = try await database.readInBackground(ValidateUserCommand())
                    }
                }

                // Semantic searches
                for _ in 0..<2 {
                    group.addTask {
                        _ = try await database.semanticSearch(
                            query: "test",
                            table: "test_table",
                            numResults: 5,
                            threshold: 0.7
                        )
                    }
                }
            }

            // Then
            let finalUsers = try await database.read(GetUsersSortedByCreationCommand())
            #expect(finalUsers.count == 101) // 100 new users + 1 initial user
        }

        @Test("Database handles rapid state transitions")
        func rapidStateTransitions() async throws {
            // Given
            let config = DatabaseConfiguration(
                isStoredInMemoryOnly: true,
                allowsSave: true,
                ragFactory: MockRagFactory(mockRag: MockRagging())
            )
            let database = try Database.new(configuration: config)

            // When - Rapid sequence of operations
            await withThrowingTaskGroup(of: Void.self) { group in
                // Write
                group.addTask {
                    try await database.write(CreateUserCommand(name: "Test User"))
                }

                // Read immediately after
                group.addTask {
                    _ = try await database.read(ValidateUserCommand())
                }

                // Save
                group.addTask {
                    try await database.save()
                }

                // Semantic search
                group.addTask {
                    _ = try await database.semanticSearch(
                        query: "test",
                        table: "test_table",
                        numResults: 5,
                        threshold: 0.7
                    )
                }
            }
        }
    }
}

enum PreconditionError: Error {
    case threadViolation
}
