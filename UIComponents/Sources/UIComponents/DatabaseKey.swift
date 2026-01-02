import Abstractions
import Database
import SwiftData
import SwiftUI

// MARK: - SwiftUI Integration

/// Environment key for the shared database instance.
public struct DatabaseKey: EnvironmentKey {
    public static let defaultValue: DatabaseProtocol = Database.instance(
        configuration: DatabaseDefaults.previewConfiguration
    )
}

extension EnvironmentValues {
    /// Database instance injected into the SwiftUI environment.
    public var database: DatabaseProtocol {
        get { self[DatabaseKey.self] }
        set { self[DatabaseKey.self] = newValue }
    }
}

/// View modifier that wires the database into the SwiftUI environment.
public struct DatabaseProvider: ViewModifier {
    private let configuration: DatabaseConfiguration

    public init(configuration: DatabaseConfiguration) {
        self.configuration = configuration
    }

    public func body(content: Content) -> some View {
        let database: Database = Database.instance(configuration: configuration)
        return content
            .environment(\.database, database)
            .modelContainer(database.modelContainer)
    }
}

extension View {
    /// Adds the default database configuration to the view environment.
    public func withDatabase(configuration: DatabaseConfiguration) -> some View {
        modifier(DatabaseProvider(configuration: configuration))
    }

    /// Adds a preview-friendly database configuration to the view environment.
    public func withDatabase() -> some View {
        modifier(DatabaseProvider(configuration: DatabaseDefaults.previewConfiguration))
    }
}

private enum DatabaseDefaults {
    static let previewConfiguration: DatabaseConfiguration = DatabaseConfiguration(
        isStoredInMemoryOnly: true,
        allowsSave: false,
        ragFactory: PreviewRagFactory()
    )
}

private struct PreviewRagFactory: RagFactory {
    func createRag(
        isStoredInMemoryOnly _: Bool,
        loadingStrategy: RagLoadingStrategy
    ) async throws -> Ragging {
        try await Task.sleep(nanoseconds: 0)
        return try await PreviewRag(
            from: "preview",
            local: nil,
            useBackgroundSession: false,
            database: .temporary,
            loadingStrategy: loadingStrategy
        )
    }

    func createRag(isStoredInMemoryOnly _: Bool) async throws -> Ragging {
        try await Task.sleep(nanoseconds: 0)
        return try await PreviewRag(
            from: "preview",
            local: nil,
            useBackgroundSession: false,
            database: .temporary
        )
    }
}

private actor PreviewRag: Ragging {
    enum PreviewError: Error {
        case unsupported
    }

    init(
        from _: String,
        local _: URL?,
        useBackgroundSession _: Bool,
        database _: DatabaseLocation,
        loadingStrategy _: RagLoadingStrategy
    ) async throws {
        try await Task.sleep(nanoseconds: 0)
    }

    init(
        from _: String,
        local _: URL?,
        useBackgroundSession _: Bool,
        database _: DatabaseLocation
    ) async throws {
        try await Task.sleep(nanoseconds: 0)
    }

    func add(
        fileURL _: URL,
        id _: UUID,
        configuration _: Configuration
    ) -> AsyncThrowingStream<Progress, Error> {
        AsyncThrowingStream { continuation in
            continuation.finish()
        }
    }

    func add(
        text _: String,
        id _: UUID,
        configuration _: Configuration
    ) -> AsyncThrowingStream<Progress, Error> {
        AsyncThrowingStream { continuation in
            continuation.finish()
        }
    }

    func semanticSearch(
        query _: String,
        numResults _: Int,
        threshold _: Double,
        table _: String
    ) async throws -> [SearchResult] {
        try await Task.sleep(nanoseconds: 0)
        return []
    }

    func getChunk(
        index _: Int,
        table _: String
    ) async throws -> SearchResult {
        try await Task.sleep(nanoseconds: 0)
        throw PreviewError.unsupported
    }

    func deleteTable(
        _ _: String
    ) async throws {
        try await Task.sleep(nanoseconds: 0)
    }

    func deleteAll() async throws {
        try await Task.sleep(nanoseconds: 0)
    }

    func delete(
        id _: UUID,
        table _: String
    ) async throws {
        try await Task.sleep(nanoseconds: 0)
    }
}
