import Abstractions
import AgentOrchestrator
import Database
import Factories
import Foundation
import LLamaCPP
import MLXSession
import ModelDownloader
import RemoteSession
import Tools
import ViewModels

protocol NodeModeServicing: Sendable {
    func start(configuration: NodeModeConfiguration) async throws
    func stop() async
    func status() async -> Bool
}

struct NodeModeServerAdapter: NodeModeServicing {
    private let server: NodeModeServer

    init(server: NodeModeServer) {
        self.server = server
    }

    func start(configuration: NodeModeConfiguration) async throws {
        try await server.start(configuration: configuration)
    }

    func stop() async {
        await server.stop()
    }

    func status() async -> Bool {
        await server.isRunning
    }
}

protocol CLIDownloader: Sendable {
    func download(sendableModel: SendableModel) -> AsyncThrowingStream<DownloadEvent, Error>
    func explorer() -> CommunityModelsExplorerProtocol
    func delete(modelLocation: String) async throws
}

struct LiveCLIDownloader: CLIDownloader {
    private let downloader: ModelDownloader

    init(downloader: ModelDownloader) {
        self.downloader = downloader
    }

    func download(sendableModel: SendableModel) -> AsyncThrowingStream<DownloadEvent, Error> {
        downloader.downloadModel(sendableModel: sendableModel)
    }

    func explorer() -> CommunityModelsExplorerProtocol {
        CommunityModelsExplorer()
    }

    func delete(modelLocation: String) async throws {
        try await downloader.deleteModel(model: modelLocation)
    }
}

struct CLIRuntime: Sendable {
    let database: DatabaseProtocol
    let orchestrator: AgentOrchestrating
    let gateway: GatewayServicing
    let tooling: Tooling
    let downloader: CLIDownloader
    let output: CLIOutput
    let nodeMode: NodeModeServicing

    func ensureInitialized() async throws {
        try await CLIAppBootstrapper.shared.ensureInitialized(database: database)
    }

    static func live(options: GlobalOptions) throws -> CLIRuntime {
        let storeURL = AppStoreLocator.sharedStoreURL(
            bundleId: AppStoreLocator.defaultBundleId,
            overridePath: options.store
        )
        try AppStoreLocator.ensureDirectoryExists(for: storeURL)

        let configStore = CLIConfigStore()
        let cliConfig = configStore.loadOrDefault()
        let resolvedWorkspace = options.workspace ?? cliConfig.workspacePath
        let workspaceRoot = resolvedWorkspace.map { URL(fileURLWithPath: $0) }

        let databaseConfig = DatabaseConfiguration(
            isStoredInMemoryOnly: false,
            allowsSave: true,
            ragFactory: DefaultRagFactory(),
            storeURL: storeURL
        )

        let database = Database.instance(configuration: databaseConfig)
        _ = CLIMetalLibraryBootstrapper.ensureMetallibAvailable()
        let mlxSession = MLXSessionFactory.create()
        let ggufSession = LlamaCPPFactory.createSession()
        let remoteSession = RemoteSessionFactory.create()
        let orchestrator = AgentOrchestratorFactory.make(
            database: database,
            mlxSession: mlxSession,
            ggufSession: ggufSession,
            options: .init(
                remoteSession: remoteSession,
                modelDownloader: ModelDownloader.shared,
                workspaceRoot: workspaceRoot
            )
        )
        let gateway = LocalGatewayService(database: database, orchestrator: orchestrator)

        let tooling = ToolManager(
            subAgentOrchestrator: nil,
            workspaceRoot: workspaceRoot,
            database: database
        )

        let output = CLIOutput(writer: StdoutOutput(), json: options.json)
        let nodeModeServer = NodeModeServerAdapter(server: NodeModeServer(gateway: gateway))

        return CLIRuntime(
            database: database,
            orchestrator: orchestrator,
            gateway: gateway,
            tooling: tooling,
            downloader: LiveCLIDownloader(downloader: ModelDownloader.shared),
            output: output,
            nodeMode: nodeModeServer
        )
    }
}

actor CLIRuntimeProviderActor {
    private var factory: @Sendable (GlobalOptions) throws -> CLIRuntime

    init(
        factory: @escaping @Sendable (GlobalOptions) throws -> CLIRuntime = {
            try CLIRuntime.live(options: $0)
        }
    ) {
        self.factory = factory
    }

    func runtime(for options: GlobalOptions) throws -> CLIRuntime {
        try factory(options)
    }

    func setFactory(_ factory: @escaping @Sendable (GlobalOptions) throws -> CLIRuntime) {
        self.factory = factory
    }

    func getFactory() -> (@Sendable (GlobalOptions) throws -> CLIRuntime) {
        factory
    }
}

enum CLIRuntimeProvider {
    private static let shared = CLIRuntimeProviderActor()

    static func runtime(for options: GlobalOptions) async throws -> CLIRuntime {
        let runtime = try await shared.runtime(for: options)
        try await runtime.ensureInitialized()
        return runtime
    }

    static func setFactory(
        _ factory: @escaping @Sendable (GlobalOptions) throws -> CLIRuntime
    ) async {
        await shared.setFactory(factory)
    }

    static func getFactory() async -> (@Sendable (GlobalOptions) throws -> CLIRuntime) {
        await shared.getFactory()
    }

    static func withFactory<T>(
        _ factory: @escaping @Sendable (GlobalOptions) throws -> CLIRuntime,
        operation: () async throws -> T
    ) async rethrows -> T {
        let previous = await shared.getFactory()
        await shared.setFactory(factory)
        do {
            let result = try await operation()
            await shared.setFactory(previous)
            return result
        } catch {
            await shared.setFactory(previous)
            throw error
        }
    }
}
