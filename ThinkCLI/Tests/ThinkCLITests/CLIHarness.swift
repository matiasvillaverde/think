import Abstractions
import AbstractionsTestUtilities
import ArgumentParser
import Database
import Foundation
import SwiftData
import Testing
import ViewModels
@testable import ThinkCLI

// MARK: - Test Helpers

struct TestRuntime {
    let runtime: CLIRuntime
    let output: BufferOutput
    let database: Database
    let gateway: StubGateway
    let tooling: StubTooling
    let downloader: StubDownloader
    let nodeMode: StubNodeMode
    let orchestrator: MockAgentOrchestrator

    static func make(
        rag: MockRagging = MockRagging(),
        gateway: StubGateway = StubGateway(),
        tooling: StubTooling = StubTooling(),
        downloader: StubDownloader = StubDownloader(),
        nodeMode: StubNodeMode = StubNodeMode(),
        orchestrator: MockAgentOrchestrator = MockAgentOrchestrator(),
        outputFormat: CLIOutputFormat = .text,
        toolAccess: CLIToolAccess = .allow
    ) async throws -> TestRuntime {
        let config = DatabaseConfiguration(
            isStoredInMemoryOnly: true,
            allowsSave: true,
            ragFactory: MockRagFactory(mockRag: rag)
        )
        let database = try Database.new(configuration: config)
        try await waitForReady(database)

        let output = BufferOutput()
        let settings = CLIRuntimeSettings(
            outputFormat: outputFormat,
            toolAccess: toolAccess,
            workspaceRoot: nil,
            verbose: false
        )
        let runtime = CLIRuntime(
            database: database,
            orchestrator: orchestrator,
            gateway: gateway,
            tooling: tooling,
            downloader: downloader,
            output: CLIOutput(writer: output, format: outputFormat),
            nodeMode: nodeMode,
            settings: settings
        )
        return TestRuntime(
            runtime: runtime,
            output: output,
            database: database,
            gateway: gateway,
            tooling: tooling,
            downloader: downloader,
            nodeMode: nodeMode,
            orchestrator: orchestrator
        )
    }
}

actor RuntimeFactoryGate {
    static let shared = RuntimeFactoryGate()

    private var locked = false
    private var waiters: [CheckedContinuation<Void, Never>] = []

    func acquire() async {
        if !locked {
            locked = true
            return
        }
        await withCheckedContinuation { cont in
            waiters.append(cont)
        }
    }

    func release() {
        if waiters.isEmpty {
            locked = false
            return
        }
        let cont = waiters.removeFirst()
        cont.resume()
    }
}

@MainActor
func withRuntime(
    _ runtime: CLIRuntime,
    operation: () async throws -> Void
) async throws {
    await RuntimeFactoryGate.shared.acquire()
    let previous = await CLIRuntimeProvider.getFactory()
    await CLIRuntimeProvider.setFactory({ _ in runtime })
    do {
        try await operation()
        await CLIRuntimeProvider.setFactory(previous)
        await RuntimeFactoryGate.shared.release()
    } catch {
        await CLIRuntimeProvider.setFactory(previous)
        await RuntimeFactoryGate.shared.release()
        throw error
    }
}

func runCLI(_ arguments: [String]) async throws {
    var command = try ThinkCLI.parseAsRoot(arguments)
    if var asyncCommand = command as? AsyncParsableCommand {
        try await asyncCommand.run()
    } else {
        try command.run()
    }
}


@MainActor
private func waitForReady(
    _ database: Database,
    timeout: TimeInterval = 2.0
) async throws {
    let deadline = Date().addingTimeInterval(timeout)
    while Date() < deadline {
        if database.status == .ready {
            return
        }
        try await Task.sleep(nanoseconds: 50_000_000)
    }
    throw DatabaseError.databaseNotReady
}

func seedChat(database: Database) async throws -> UUID {
    _ = try await database.write(
        ModelCommands.CreateLocalModel(
            name: "Lang",
            backend: .mlx,
            type: .language,
            parameters: 1,
            ramNeeded: 1,
            size: 1,
            architecture: .llama,
            locationLocal: "/tmp/lang",
            locationBookmark: nil
        )
    )
    _ = try await database.write(
        ModelCommands.CreateLocalModel(
            name: "Image",
            backend: .mlx,
            type: .diffusion,
            parameters: 1,
            ramNeeded: 1,
            size: 1,
            architecture: .stableDiffusion,
            locationLocal: "/tmp/image",
            locationBookmark: nil
        )
    )
    let personalityId = try await database.write(PersonalityCommands.WriteDefault())
    return try await database.write(ChatCommands.Create(personality: personalityId))
}

struct ModelProgressReadCommand: ReadCommand {
    let id: UUID

    func execute(
        in context: ModelContext,
        userId: PersistentIdentifier?,
        rag: Ragging?
    ) throws -> Double? {
        let descriptor = FetchDescriptor<Model>(
            predicate: #Predicate<Model> { $0.id == id }
        )
        return try context.fetch(descriptor).first?.downloadProgress
    }
}

// MARK: - Stubs

actor StubGateway: GatewayServicing {
    private var sessions: [GatewaySession] = []
    private var historyBySession: [UUID: [GatewayMessage]] = [:]
    private(set) var lastSendOptions: GatewaySendOptions?
    private var lastSendSessionId: UUID?
    private var sendResult: GatewaySendResult?
    private var sendDelayNanoseconds: UInt64 = 0

    func setSessions(_ sessions: [GatewaySession]) {
        self.sessions = sessions
    }

    func setHistory(sessionId: UUID, messages: [GatewayMessage]) {
        historyBySession[sessionId] = messages
    }

    func setSendResult(_ result: GatewaySendResult) {
        sendResult = result
    }

    func setSendDelayNanoseconds(_ delay: UInt64) {
        sendDelayNanoseconds = delay
    }

    func createSession(title: String?) async throws -> GatewaySession {
        let session = GatewaySession(
            id: UUID(),
            title: title ?? "New Session",
            createdAt: Date(),
            updatedAt: Date()
        )
        sessions.append(session)
        return session
    }

    func listSessions() async throws -> [GatewaySession] {
        sessions
    }

    func getSession(id: UUID) async throws -> GatewaySession {
        if let session = sessions.first(where: { $0.id == id }) {
            return session
        }
        throw GatewayError.sessionNotFound
    }

    func history(
        sessionId: UUID,
        options: GatewayHistoryOptions
    ) async throws -> [GatewayMessage] {
        historyBySession[sessionId] ?? []
    }

    func send(
        sessionId: UUID,
        input: String,
        options: GatewaySendOptions
    ) async throws -> GatewaySendResult {
        lastSendSessionId = sessionId
        lastSendOptions = options
        if sendDelayNanoseconds > 0 {
            try await Task.sleep(nanoseconds: sendDelayNanoseconds)
        }
        if let sendResult {
            return sendResult
        }
        return GatewaySendResult(messageId: UUID(), assistantMessage: nil)
    }

    func spawnSubAgent(
        sessionId: UUID,
        request: SubAgentRequest
    ) async throws -> SubAgentResult {
        throw GatewayError.subAgentUnavailable
    }
}

actor StubTooling: Tooling {
    private var configured: Set<ToolIdentifier> = []
    private var definitions: [ToolDefinition] = []
    private var lastToolRequests: [ToolRequest] = []

    func configureTool(identifiers: Set<ToolIdentifier>) async {
        configured = identifiers
    }

    func clearTools() async {
        configured.removeAll()
    }

    func getToolDefinitions(for identifiers: Set<ToolIdentifier>) async -> [ToolDefinition] {
        definitions.filter { definition in
            identifiers.contains { identifier in
                identifier.toolName == definition.name
            }
        }
    }

    func getAllToolDefinitions() async -> [ToolDefinition] {
        definitions
    }

    func executeTools(toolRequests: [ToolRequest]) async -> [ToolResponse] {
        lastToolRequests = toolRequests
        return toolRequests.map { request in
            ToolResponse(requestId: request.id, toolName: request.name, result: request.arguments)
        }
    }

    func configureSemanticSearch(
        database: DatabaseProtocol,
        chatId: UUID,
        fileTitles: [String]
    ) async {}

    func setDefinitions(_ definitions: [ToolDefinition]) {
        self.definitions = definitions
    }

    func lastRequests() -> [ToolRequest] {
        lastToolRequests
    }
}

actor StubDownloader: CLIDownloader {
    nonisolated let explorerInstance: CommunityModelsExplorerProtocol
    nonisolated let events: [DownloadEvent]
    private var deleted: [String] = []
    private var downloaded: [SendableModel] = []

    init(
        explorerInstance: CommunityModelsExplorerProtocol = MockCommunityModelsExplorer(),
        events: [DownloadEvent] = []
    ) {
        self.explorerInstance = explorerInstance
        self.events = events
    }

    nonisolated func download(
        sendableModel: SendableModel
    ) -> AsyncThrowingStream<DownloadEvent, Error> {
        Task { await recordDownload(sendableModel) }
        return AsyncThrowingStream { continuation in
            for event in events {
                continuation.yield(event)
            }
            continuation.finish()
        }
    }

    nonisolated func explorer() -> CommunityModelsExplorerProtocol {
        explorerInstance
    }

    func delete(modelLocation: String) async throws {
        deleted.append(modelLocation)
    }

    func lastDownloaded() -> SendableModel? {
        downloaded.last
    }

    private func recordDownload(_ model: SendableModel) {
        downloaded.append(model)
    }
}

actor StubNodeMode: NodeModeServicing {
    private var running: Bool = false

    func start(configuration: NodeModeConfiguration) async throws {
        running = true
    }

    func stop() async {
        running = false
    }

    func status() async -> Bool {
        running
    }
}
