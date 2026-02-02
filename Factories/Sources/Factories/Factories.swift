import Abstractions
import Database
import Foundation
import ModelDownloader
import Rag
import ViewModels

/// Factories namespace for dependency injection components
public enum Factories {}

public struct DefaultRagFactory: RagFactory {
    public init() {
        // Initialize default RAG factory
    }

    public func createRag(
        isStoredInMemoryOnly: Bool,
        loadingStrategy: RagLoadingStrategy
    ) async throws -> Ragging {
        let modelURL: URL? = RagResourceLocator.locateModelDirectory()

        return try await Rag(
            local: modelURL,
            database: isStoredInMemoryOnly ? .inMemory : .uri(SQLiteLocation.getHiddenDBPath()),
            loadingStrategy: loadingStrategy
        )
    }

    public func createRag(isStoredInMemoryOnly: Bool) async throws -> Ragging {
        try await createRag(
            isStoredInMemoryOnly: isStoredInMemoryOnly,
            loadingStrategy: .lazy
        )
    }
}

internal enum SQLiteLocation {
    static func getHiddenDBPath() -> String {
        let fileManager: FileManager = FileManager.default
        guard let libraryPath = fileManager.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first else {
            fatalError("Could not access Application Support directory")
        }

        // Create app-specific directory if it doesn't exist
        let bundleIdentifier: String = Bundle.main.bundleIdentifier ?? ""
        let appDirectory: URL = libraryPath.appendingPathComponent(bundleIdentifier)

        try? fileManager.createDirectory(at: appDirectory, withIntermediateDirectories: true)

        // Add an extra hidden directory for additional security
        let hiddenDirectory: URL = appDirectory.appendingPathComponent(".hidden")
        try? fileManager.createDirectory(at: hiddenDirectory, withIntermediateDirectories: true)

        return hiddenDirectory.appendingPathComponent("database.db").path
    }
}
// MARK: - Database Configuration

extension DatabaseConfiguration {
    /// Default database configuration for production use
    public static let `default`: DatabaseConfiguration = DatabaseConfiguration(
        isStoredInMemoryOnly: false,
        allowsSave: true,
        ragFactory: DefaultRagFactory()
    )

    /// In-memory only database configuration for testing
    public static let inMemoryOnly: DatabaseConfiguration = .init(
        isStoredInMemoryOnly: true,
        allowsSave: false,
        ragFactory: DefaultRagFactory()
    )
}

// MARK: - ModelDownloaderViewModel Factory

/// Factory for creating ModelDownloaderViewModel instances
public enum ModelDownloaderViewModelFactory {
    /// Creates a ModelDownloaderViewModel with the provided database
    /// - Parameter database: The database to use for model storage
    /// - Returns: A configured ModelDownloaderViewModel instance
    public static func create(database: DatabaseProtocol) -> ModelDownloaderViewModeling {
        ModelDownloaderViewModel(
            database: database,
            modelDownloader: ModelDownloader(),
            communityExplorer: CommunityModelsExplorer()
        )
    }
}
