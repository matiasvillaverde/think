import Abstractions
import ContextBuilder
import Database
import Foundation
import ImageGenerator
import ModelDownloader
import Tools

/// Factory for creating and managing AgentOrchestrating instances
public enum AgentOrchestratorFactory {
    private static let lock: NSLock = NSLock()

    // Use nonisolated(unsafe) to suppress concurrency warning since we're using a lock
    nonisolated(unsafe) private static var sharedInstance: AgentOrchestrating?

    /// Returns the shared AgentOrchestrating instance
    /// Creates it lazily on first access
    /// - Parameters:
    ///   - database: The database to use for persistence
    ///   - mlxSession: The MLX session for language models
    ///   - ggufSession: The GGUF session for language models
    ///   - remoteSession: Optional remote session for API-based models
    ///   - modelDownloader: The model downloader for resolving model paths
    /// - Returns: The shared AgentOrchestrating instance
    public static func shared(
        database: DatabaseProtocol,
        mlxSession: LLMSession,
        ggufSession: LLMSession,
        remoteSession: LLMSession? = nil,
        modelDownloader: ModelDownloaderProtocol? = nil
    ) -> AgentOrchestrating {
        lock.lock()
        defer { lock.unlock() }

        if let existingInstance = sharedInstance {
            return existingInstance
        }

        let newInstance: AgentOrchestrating = createOrchestrator(
            database: database,
            mlxSession: mlxSession,
            ggufSession: ggufSession,
            remoteSession: remoteSession,
            modelDownloader: modelDownloader ?? ModelDownloader.shared
        )
        sharedInstance = newInstance
        return newInstance
    }

    /// Creates a new AgentOrchestrator instance
    /// Internal method that builds all dependencies
    private static func createOrchestrator(
        database: DatabaseProtocol,
        mlxSession: LLMSession,
        ggufSession: LLMSession,
        remoteSession: LLMSession?,
        modelDownloader: ModelDownloaderProtocol
    ) -> AgentOrchestrating {
        // Create image generator
        let imageGenerator: ImageGenerating = ImageGenerator(
            modelDownloader: modelDownloader
        )

        // Create model coordinator
        let modelCoordinator: ModelStateCoordinator = ModelStateCoordinator(
            database: database,
            mlxSession: mlxSession,
            ggufSession: ggufSession,
            imageGenerator: imageGenerator,
            modelDownloader: modelDownloader,
            remoteSession: remoteSession
        )

        // Create message persistor
        let persistor: MessagePersistor = MessagePersistor(database: database as DatabaseProtocol)

        // Create tooling manager
        let tooling: Tooling = ToolManager()

        // Create context builder with tooling
        let contextBuilder: ContextBuilder = ContextBuilder(tooling: tooling)

        // Create and return the orchestrator
        return AgentOrchestrator(
            modelCoordinator: modelCoordinator,
            persistor: persistor,
            contextBuilder: contextBuilder,
            tooling: tooling
        )
    }

    /// Resets the shared instance
    /// Used primarily for testing to ensure a clean state
    internal static func reset() {
        lock.lock()
        defer { lock.unlock() }
        sharedInstance = nil
    }
}
