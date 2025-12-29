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

    /// Creates a new AgentOrchestrator instance without caching.
    /// Use this for background tasks to avoid interfering with the shared orchestrator.
    public static func make(
        database: DatabaseProtocol,
        mlxSession: LLMSession,
        ggufSession: LLMSession,
        remoteSession: LLMSession? = nil,
        modelDownloader: ModelDownloaderProtocol? = nil
    ) -> AgentOrchestrating {
        createOrchestrator(
            database: database,
            mlxSession: mlxSession,
            ggufSession: ggufSession,
            remoteSession: remoteSession,
            modelDownloader: modelDownloader ?? ModelDownloader.shared
        )
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
        let workspaceRoot: URL? = resolveWorkspaceRoot()
        let inputs: OrchestratorInputs = OrchestratorInputs(
            database: database,
            mlxSession: mlxSession,
            ggufSession: ggufSession,
            remoteSession: remoteSession,
            modelDownloader: modelDownloader,
            workspaceRoot: workspaceRoot
        )
        let components: OrchestratorComponents = createComponents(inputs: inputs)
        return AgentOrchestrator(
            modelCoordinator: components.modelCoordinator,
            persistor: components.persistor,
            contextBuilder: ContextBuilder(tooling: components.tooling),
            tooling: components.tooling,
            workspaceContextProvider: components.workspaceProviders.contextProvider,
            workspaceSkillLoader: components.workspaceProviders.skillLoader,
            workspaceMemoryLoader: components.workspaceProviders.memoryLoader
        )
    }

    internal struct OrchestratorInputs {
        internal let database: DatabaseProtocol
        internal let mlxSession: LLMSession
        internal let ggufSession: LLMSession
        internal let remoteSession: LLMSession?
        internal let modelDownloader: ModelDownloaderProtocol
        internal let workspaceRoot: URL?
    }

    internal struct OrchestratorComponents {
        internal let modelCoordinator: ModelStateCoordinator
        internal let persistor: MessagePersistor
        internal let tooling: Tooling
        internal let workspaceProviders: WorkspaceProviders
    }

    private static func createComponents(
        inputs: OrchestratorInputs
    ) -> OrchestratorComponents {
        let dependencies: ModelCoordinatorDependencies = createModelCoordinatorDependencies(inputs: inputs)
        let modelCoordinator: ModelStateCoordinator = createModelCoordinator(dependencies: dependencies)
        let persistor: MessagePersistor = createPersistor(database: inputs.database)
        let subAgentCoordinator: SubAgentCoordinator = createSubAgentCoordinator(
            database: inputs.database,
            modelCoordinator: modelCoordinator,
            workspaceRoot: inputs.workspaceRoot
        )
        let tooling: Tooling = createTooling(
            subAgentCoordinator: subAgentCoordinator,
            workspaceRoot: inputs.workspaceRoot,
            database: inputs.database
        )
        let workspaceProviders: WorkspaceProviders = createWorkspaceProviders(
            workspaceRoot: inputs.workspaceRoot
        )

        return OrchestratorComponents(
            modelCoordinator: modelCoordinator,
            persistor: persistor,
            tooling: tooling,
            workspaceProviders: workspaceProviders
        )
    }

    private static func createModelCoordinatorDependencies(
        inputs: OrchestratorInputs
    ) -> ModelCoordinatorDependencies {
        let imageGenerator: ImageGenerating = createImageGenerator(
            modelDownloader: inputs.modelDownloader
        )
        return ModelCoordinatorDependencies(
            database: inputs.database,
            mlxSession: inputs.mlxSession,
            ggufSession: inputs.ggufSession,
            imageGenerator: imageGenerator,
            modelDownloader: inputs.modelDownloader,
            remoteSession: inputs.remoteSession
        )
    }

    private static func resolveWorkspaceRoot() -> URL? {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
    }

    private static func createSubAgentCoordinator(
        database: DatabaseProtocol,
        modelCoordinator: ModelStateCoordinator,
        workspaceRoot: URL?
    ) -> SubAgentCoordinator {
        SubAgentCoordinator(
            database: database,
            modelCoordinator: modelCoordinator,
            workspaceRoot: workspaceRoot
        )
    }

    internal struct WorkspaceProviders {
        internal let contextProvider: WorkspaceContextProvider?
        internal let skillLoader: WorkspaceSkillLoader?
        internal let memoryLoader: WorkspaceMemoryLoader?
    }

    private static func createWorkspaceProviders(
        workspaceRoot: URL?
    ) -> WorkspaceProviders {
        guard let workspaceRoot else {
            return WorkspaceProviders(
                contextProvider: nil,
                skillLoader: nil,
                memoryLoader: nil
            )
        }

        return WorkspaceProviders(
            contextProvider: WorkspaceContextProvider(rootURL: workspaceRoot),
            skillLoader: WorkspaceSkillLoader(rootURL: workspaceRoot),
            memoryLoader: WorkspaceMemoryLoader(rootURL: workspaceRoot)
        )
    }

    private struct ModelCoordinatorDependencies {
        let database: DatabaseProtocol
        let mlxSession: LLMSession
        let ggufSession: LLMSession
        let imageGenerator: ImageGenerating
        let modelDownloader: ModelDownloaderProtocol
        let remoteSession: LLMSession?
    }

    private static func createImageGenerator(
        modelDownloader: ModelDownloaderProtocol
    ) -> ImageGenerating {
        ImageGenerator(modelDownloader: modelDownloader)
    }

    private static func createModelCoordinator(
        dependencies: ModelCoordinatorDependencies
    ) -> ModelStateCoordinator {
        ModelStateCoordinator(
            database: dependencies.database,
            mlxSession: dependencies.mlxSession,
            ggufSession: dependencies.ggufSession,
            imageGenerator: dependencies.imageGenerator,
            modelDownloader: dependencies.modelDownloader,
            remoteSession: dependencies.remoteSession
        )
    }

    private static func createPersistor(database: DatabaseProtocol) -> MessagePersistor {
        MessagePersistor(database: database as DatabaseProtocol)
    }

    private static func createTooling(
        subAgentCoordinator: SubAgentCoordinator,
        workspaceRoot: URL?,
        database: DatabaseProtocol
    ) -> Tooling {
        ToolManager(
            subAgentOrchestrator: subAgentCoordinator,
            workspaceRoot: workspaceRoot,
            database: database
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
