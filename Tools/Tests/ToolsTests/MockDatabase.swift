@testable import Abstractions
import Foundation
@testable import Tools

/// Mock database for testing
internal actor MockDatabase: DatabaseProtocol {
    internal struct SemanticSearchCall: Sendable, Equatable {
        let query: String
        let table: String
        let numResults: Int
        let threshold: Double
    }

    internal private(set) var semanticSearchCalls: [SemanticSearchCall] = []

    internal var lastSemanticSearchCall: SemanticSearchCall? {
        semanticSearchCalls.last
    }
    /// Database status
    @MainActor internal var status: DatabaseStatus {
        .ready
    }

    /// Write command implementation
    @MainActor
    internal func write<T: WriteCommand>(_: T) async throws -> T.Result {
        // Mock implementation - simulate async work
        await Task.yield()
        throw ToolError("Mock database write not implemented")
    }

    /// Read command implementation
    @MainActor
    internal func read<T: ReadCommand>(_: T) async throws -> T.Result {
        // Mock implementation - simulate async work
        await Task.yield()
        throw ToolError("Mock database read not implemented")
    }

    /// Execute anonymous command
    @MainActor
    internal func execute<T: AnonymousCommand>(_: T) async throws -> T.Result {
        // Mock implementation - simulate async work
        await Task.yield()
        throw ToolError("Mock database execute not implemented")
    }

    /// Save database
    @MainActor
    internal func save() throws {
        // No-op for mock
    }

    /// Write in background
    internal func writeInBackground<T: WriteCommand>(_: T) async throws {
        // Mock implementation - simulate async work
        await Task.yield()
    }

    /// Read in background
    internal func readInBackground<T: ReadCommand>(_: T) async throws -> T.Result {
        // Mock implementation - simulate async work
        await Task.yield()
        throw ToolError("Mock database readInBackground not implemented")
    }

    /// Semantic search implementation
    internal func semanticSearch(
        query: String,
        table: String,
        numResults: Int,
        threshold: Double
    ) async throws -> [SearchResult] {
        // Simulate async work
        await Task.yield()

        semanticSearchCalls.append(SemanticSearchCall(
            query: query,
            table: table,
            numResults: numResults,
            threshold: threshold
        ))

        // Return mock search results
        let mockScore1: Double = 0.9
        let mockScore2: Double = 0.8
        let mockScore3: Double = 0.7
        let mockScore4: Double = 0.6
        let mockScore5: Double = 0.5
        let rowId0: UInt = 0
        let rowId1: UInt = 1
        let rowId2: UInt = 2
        let rowId3: UInt = 3
        let rowId4: UInt = 4

        return [
            SearchResult(id: UUID(), text: "Mock result 1", keywords: "test", score: mockScore1, rowId: rowId0),
            SearchResult(id: UUID(), text: "Mock result 2", keywords: "test", score: mockScore2, rowId: rowId1),
            SearchResult(id: UUID(), text: "Mock result 3", keywords: "test", score: mockScore3, rowId: rowId2),
            SearchResult(id: UUID(), text: "Mock result 4", keywords: "test", score: mockScore4, rowId: rowId3),
            SearchResult(id: UUID(), text: "Mock result 5", keywords: "test", score: mockScore5, rowId: rowId4)
        ]
    }
}
