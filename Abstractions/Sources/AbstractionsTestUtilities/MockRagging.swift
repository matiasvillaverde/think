import Foundation
import Abstractions

public final actor MockRagging: Ragging, @unchecked Sendable {
    // MARK: - Call Tracking Types
    public struct SemanticSearchCall: Sendable {
        public let query: String
        public let numResults: Int
        public let threshold: Double
        public let table: String
    }

    public struct AddFileCall: Sendable {
        public let url: URL
        public let id: UUID
        public let config: Configuration
    }

    public struct AddTextCall: Sendable {
        public let text: String
        public let id: UUID
        public let config: Configuration
    }

    public struct GetChunkCall: Sendable {
        public let index: Int
        public let table: String
    }

    public struct DeleteIDCall: Sendable, Equatable {
        public let table: String
        public let id: UUID
    }

    // MARK: - Configuration
    private let initializationDelay: TimeInterval
    private let error: Error?
    private let searchResults: [SearchResult]

    // MARK: - Call Tracking
    public var semanticSearchCalls: [SemanticSearchCall] = []
    public var addFileCalls: [AddFileCall] = []
    public var addTextCalls: [AddTextCall] = []
    public var getChunkCalls: [GetChunkCall] = []
    public var deleteTableCalls: [String] = []

    public var deleteIDCalls: [DeleteIDCall] = []

    // MARK: - Initialization
    public init(
        searchResults: [SearchResult] = [],
        initializationDelay: TimeInterval = 0.5,
        error: Error? = nil
    ) {
        self.searchResults = searchResults
        self.initializationDelay = initializationDelay
        self.error = error
    }

    public init(
        from hubRepoId: String,
        local: URL?,
        useBackgroundSession: Bool,
        database: DatabaseLocation,
        loadingStrategy: RagLoadingStrategy
    ) async throws {
        self.searchResults = []
        self.initializationDelay = 0.5
        self.error = nil
        try await Task.sleep(nanoseconds: UInt64(initializationDelay * 1_000_000_000))

        if let error {
            throw error
        }
    }

    public init(
        from hubRepoId: String,
        local: URL?,
        useBackgroundSession: Bool,
        database: DatabaseLocation
    ) async throws {
        try await self.init(
            from: hubRepoId,
            local: local,
            useBackgroundSession: useBackgroundSession,
            database: database,
            loadingStrategy: .lazy
        )
    }

    // MARK: - File Operations
    public func add(
        fileURL: URL,
        id: UUID,
        configuration: Configuration
    ) -> AsyncThrowingStream<Progress, Error> {
        addFileCalls.append(AddFileCall(url: fileURL, id: id, config: configuration))

        return AsyncThrowingStream { continuation in
            if let error = self.error {
                continuation.finish(throwing: error)
            } else {
                continuation.yield(Progress(totalUnitCount: 100))
                continuation.finish()
            }
        }
    }

    public func add(
        text: String,
        id: UUID,
        configuration: Configuration
    ) -> AsyncThrowingStream<Progress, Error> {
        addTextCalls.append(AddTextCall(text: text, id: id, config: configuration))

        return AsyncThrowingStream { continuation in
            if let error = self.error {
                continuation.finish(throwing: error)
            } else {
                continuation.yield(Progress(totalUnitCount: 100))
                continuation.finish()
            }
        }
    }

    // MARK: - Search Operations
    public func semanticSearch(
        query: String,
        numResults: Int,
        threshold: Double,
        table: String
    ) throws -> [SearchResult] {
        semanticSearchCalls.append(
            SemanticSearchCall(query: query, numResults: numResults, threshold: threshold, table: table)
        )

        if let error {
            throw error
        }

        // Return either all results or limited by numResults
        return Array(searchResults.prefix(numResults))
    }

    public func getChunk(
        index: Int,
        table: String
    ) throws -> SearchResult {
        getChunkCalls.append(GetChunkCall(index: index, table: table))

        if let error {
            throw error
        }

        guard index < searchResults.count else {
            throw RAGError.indexOutOfBounds
        }

        return searchResults[index]
    }

    public func deleteTable(
        _ table: String
    ) throws {
        deleteTableCalls.append(table)

        if let error {
            throw error
        }
    }

    public func deleteAll() {
        // No-op for mock
    }

    public func delete(id: UUID, table: String) {
        deleteIDCalls.append(DeleteIDCall(table: table, id: id))
    }

    // MARK: - Test Helpers
    public func reset() {
        semanticSearchCalls.removeAll()
        addFileCalls.removeAll()
        addTextCalls.removeAll()
        getChunkCalls.removeAll()
        deleteTableCalls.removeAll()
        deleteIDCalls.removeAll()
    }

    public var lastSemanticSearchCall: (query: String, numResults: Int, threshold: Double, table: String)? {
        guard let call = semanticSearchCalls.last else {
            return nil
        }
        return (call.query, call.numResults, call.threshold, call.table)
    }

    public var lastAddFileCall: (url: URL, id: UUID, config: Configuration)? {
        guard let call = addFileCalls.last else {
            return nil
        }
        return (call.url, call.id, call.config)
    }

    public var lastAddTextCall: (text: String, id: UUID, config: Configuration)? {
        guard let call = addTextCalls.last else {
            return nil
        }
        return (call.text, call.id, call.config)
    }

    public var lastGetChunkCall: (index: Int, table: String)? {
        guard let call = getChunkCalls.last else {
            return nil
        }
        return (call.index, call.table)
    }

    public var lastDeleteTableCall: String? {
        deleteTableCalls.last
    }
}
