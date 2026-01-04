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

    static func live(options: GlobalOptions) throws -> CLIRuntime {
        let storeURL = AppStoreLocator.sharedStoreURL(
            bundleId: AppStoreLocator.defaultBundleId,
            overridePath: options.store
        )
        try AppStoreLocator.ensureDirectoryExists(for: storeURL)

        let databaseConfig = DatabaseConfiguration(
            isStoredInMemoryOnly: false,
            allowsSave: true,
            ragFactory: DefaultRagFactory(),
            storeURL: storeURL
        )

        let database = Database.instance(configuration: databaseConfig)
        let mlxSession = MLXSessionFactory.create()
        let ggufSession = LlamaCPPFactory.createSession()
        let remoteSession = RemoteSessionFactory.create()
        let orchestrator = AgentOrchestratorFactory.make(
            database: database,
            mlxSession: mlxSession,
            ggufSession: ggufSession,
            remoteSession: remoteSession,
            modelDownloader: ModelDownloader.shared
        )
        let gateway = LocalGatewayService(database: database, orchestrator: orchestrator)

        let workspaceRoot = options.workspace.map { URL(fileURLWithPath: $0) }
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

enum CLIRuntimeProvider {
    static var factory: (GlobalOptions) throws -> CLIRuntime = { try CLIRuntime.live(options: $0) }

    static func runtime(for options: GlobalOptions) throws -> CLIRuntime {
        try factory(options)
    }
}
