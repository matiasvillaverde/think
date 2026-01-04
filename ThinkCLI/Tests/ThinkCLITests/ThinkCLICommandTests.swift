import Abstractions
import AbstractionsTestUtilities
import Database
import Foundation
import SwiftData
import Testing
@testable import ThinkCLI

@Suite("ThinkCLI Command Tests", .serialized)
struct ThinkCLICommandTests {
    @Test("Gateway start/stop and status")
    func gatewayStartStop() async throws {
        let context = try await TestRuntime.make()
        try await withRuntime(context.runtime) {
            var start = GatewayCommand.Start()
            start.global = GlobalOptions()
            start.port = 9_876
            start.once = true
            try await start.run()

            var status = GatewayCommand.Status()
            status.global = GlobalOptions()
            try await status.run()
        }

        let running = await context.nodeMode.status()
        #expect(running == false)
        #expect(context.output.lines.contains { $0.contains("Gateway server running") })
    }

    @Test("Chat list/create/get/send/history")
    func chatCommands() async throws {
        let context = try await TestRuntime.make()
        let session = GatewaySession(
            id: UUID(),
            title: "Test Chat",
            createdAt: Date(),
            updatedAt: Date()
        )
        await context.gateway.setSessions([session])
        await context.gateway.setHistory(sessionId: session.id, messages: [
            GatewayMessage(id: UUID(), role: .user, content: "Hi", createdAt: Date()),
            GatewayMessage(id: UUID(), role: .assistant, content: "Hello!", createdAt: Date())
        ])
        await context.gateway.setSendResult(
            GatewaySendResult(
                messageId: UUID(),
                assistantMessage: GatewayMessage(
                    id: UUID(),
                    role: .assistant,
                    content: "Response",
                    createdAt: Date()
                )
            )
        )

        try await withRuntime(context.runtime) {
            var list = ChatCommand.List()
            list.global = GlobalOptions()
            try await list.run()

            var get = ChatCommand.Get()
            get.global = GlobalOptions()
            get.id = session.id.uuidString
            try await get.run()

            var history = ChatCommand.History()
            history.global = GlobalOptions()
            history.session = session.id.uuidString
            history.limit = 10
            try await history.run()

            var send = ChatCommand.Send()
            send.global = GlobalOptions()
            send.session = session.id.uuidString
            send.input = "Hello"
            try await send.run()
        }

        #expect(context.output.lines.contains { $0.contains("Test Chat") })
        #expect(context.output.lines.contains { $0.contains("Response") })
    }

    @Test("Chat rename/delete uses database")
    func chatRenameDelete() async throws {
        let context = try await TestRuntime.make()
        let chatId = try await seedChat(database: context.database)

        try await withRuntime(context.runtime) {
            var rename = ChatCommand.Rename()
            rename.global = GlobalOptions()
            rename.session = chatId.uuidString
            rename.title = "Renamed"
            try await rename.run()

            var delete = ChatCommand.Delete()
            delete.global = GlobalOptions()
            delete.session = chatId.uuidString
            try await delete.run()
        }

        await #expect(throws: DatabaseError.chatNotFound) {
            _ = try await context.database.read(ChatCommands.Read(chatId: chatId))
        }
    }

    @Test("Models list/info/add/remove")
    func modelCommands() async throws {
        let context = try await TestRuntime.make()
        let modelId = try await context.database.write(
            ModelCommands.CreateLocalModel(
                name: "Local Model",
                backend: .mlx,
                type: .language,
                parameters: 1,
                ramNeeded: 1,
                size: 1,
                architecture: .llama,
                locationLocal: "/tmp/model",
                locationBookmark: nil
            )
        )

        try await withRuntime(context.runtime) {
            var list = ModelsCommand.List()
            list.global = GlobalOptions()
            try await list.run()

            var info = ModelsCommand.Info()
            info.global = GlobalOptions()
            info.id = modelId.uuidString
            try await info.run()

            var remove = ModelsCommand.Remove()
            remove.global = GlobalOptions()
            remove.id = modelId.uuidString
            try await remove.run()
        }

        let state = try await context.database.read(ModelStateReadCommand(id: modelId))
        #expect(state == .notDownloaded)
    }

    @Test("Models download updates progress")
    func modelDownload() async throws {
        let mockRag = MockRagging()
        let explorer = MockCommunityModelsExplorer()
        let discovered = DiscoveredModel.createMock(
            id: "mlx-community/test-model",
            detectedBackends: [.mlx]
        )
        let sendable = SendableModel(
            id: UUID(),
            ramNeeded: 0,
            modelType: .language,
            location: discovered.id,
            architecture: .llama,
            backend: .mlx,
            locationKind: .huggingFace
        )
        explorer.discoverModelResponses[discovered.id] = discovered
        explorer.prepareForDownloadResult = sendable

        let modelInfo = ModelInfo(
            id: sendable.id,
            name: sendable.location,
            backend: sendable.backend,
            location: URL(fileURLWithPath: "/tmp/\(sendable.location)"),
            totalSize: 1,
            downloadDate: Date()
        )

        let downloader = StubDownloader(
            explorerInstance: explorer,
            events: [
                .progress(
                    DownloadProgress(
                        bytesDownloaded: 1,
                        totalBytes: 2,
                        filesCompleted: 0,
                        totalFiles: 1
                    )
                ),
                .completed(modelInfo)
            ]
        )

        let context = try await TestRuntime.make(
            rag: mockRag,
            downloader: downloader
        )

        try await withRuntime(context.runtime) {
            var download = ModelsCommand.Download()
            download.global = GlobalOptions()
            download.modelId = discovered.id
            try await download.run()
        }

        let progress = try await context.database.read(ModelProgressReadCommand(id: sendable.id))
        #expect(progress == 1.0)
    }

    @Test("Tools list and run")
    func toolsCommands() async throws {
        let tooling = StubTooling()
        let definition = ToolDefinition(
            name: "browser.search",
            description: "Search",
            schema: "{}"
        )
        await tooling.setDefinitions([definition])
        let context = try await TestRuntime.make(tooling: tooling)

        try await withRuntime(context.runtime) {
            var list = ToolsCommand.List()
            list.global = GlobalOptions()
            try await list.run()

            var run = ToolsCommand.Run()
            run.global = GlobalOptions()
            run.name = "browser.search"
            run.args = "{\"q\":\"swift\"}"
            try await run.run()
        }

        let requests = await tooling.lastRequests()
        #expect(requests.first?.name == "browser.search")
    }

    @Test("RAG index/search/delete")
    func ragCommands() async throws {
        let mockRag = MockRagging(searchResults: [
            SearchResult(id: UUID(), text: "hello", keywords: "hello", score: 0.1, rowId: 0)
        ])
        let context = try await TestRuntime.make(rag: mockRag)
        let table = RagTableName.chatTableName(chatId: UUID())

        try await withRuntime(context.runtime) {
            var index = RagCommand.Index()
            index.global = GlobalOptions()
            index.table = table
            index.text = "hello world"
            try await index.run()

            var search = RagCommand.Search()
            search.global = GlobalOptions()
            search.table = table
            search.query = "hello"
            try await search.run()

            var delete = RagCommand.Delete()
            delete.global = GlobalOptions()
            delete.table = table
            delete.id = UUID().uuidString
            try await delete.run()
        }

        let addCalls = await mockRag.addTextCalls
        #expect(addCalls.isEmpty == false)
    }

    @Test("Skills list/enable/disable")
    func skillsCommands() async throws {
        let context = try await TestRuntime.make()
        let skillId = try await context.database.write(
            SkillCommands.Create(
                name: "Test Skill",
                skillDescription: "desc",
                instructions: "do it",
                tools: ["browser.search"],
                isEnabled: false
            )
        )

        try await withRuntime(context.runtime) {
            var list = SkillsCommand.List()
            list.global = GlobalOptions()
            try await list.run()

            var enable = SkillsCommand.Enable()
            enable.global = GlobalOptions()
            enable.id = skillId.uuidString
            try await enable.run()

            var disable = SkillsCommand.Disable()
            disable.global = GlobalOptions()
            disable.id = skillId.uuidString
            try await disable.run()
        }

        let skill = try await context.database.read(SkillCommands.Read(skillId: skillId))
        #expect(skill.isEnabled == false)
    }

    @Test("Schedules create/update/enable/disable/delete")
    func schedulesCommands() async throws {
        let context = try await TestRuntime.make()
        let cronExpression = "0 0 * * *"

        try await withRuntime(context.runtime) {
            var create = SchedulesCommand.Create()
            create.global = GlobalOptions()
            create.title = "Daily"
            create.prompt = "Run"
            create.cron = cronExpression
            create.kind = "cron"
            create.action = "text"
            try await create.run()

            var list = SchedulesCommand.List()
            list.global = GlobalOptions()
            try await list.run()
        }

        let schedules = try await context.database.read(AutomationScheduleCommands.List())
        let scheduleId = try #require(schedules.first?.id)

        try await withRuntime(context.runtime) {
            var update = SchedulesCommand.Update()
            update.global = GlobalOptions()
            update.id = scheduleId.uuidString
            update.title = "Updated"
            try await update.run()

            var enable = SchedulesCommand.Enable()
            enable.global = GlobalOptions()
            enable.id = scheduleId.uuidString
            try await enable.run()

            var disable = SchedulesCommand.Disable()
            disable.global = GlobalOptions()
            disable.id = scheduleId.uuidString
            try await disable.run()

            var delete = SchedulesCommand.Delete()
            delete.global = GlobalOptions()
            delete.id = scheduleId.uuidString
            try await delete.run()
        }

        let remaining = try await context.database.read(AutomationScheduleCommands.List())
        #expect(remaining.isEmpty)
    }
}

// MARK: - Test Helpers

private struct TestRuntime {
    let runtime: CLIRuntime
    let output: BufferOutput
    let database: Database
    let gateway: StubGateway
    let tooling: StubTooling
    let downloader: StubDownloader
    let nodeMode: StubNodeMode

    static func make(
        rag: MockRagging = MockRagging(),
        gateway: StubGateway = StubGateway(),
        tooling: StubTooling = StubTooling(),
        downloader: StubDownloader = StubDownloader(),
        nodeMode: StubNodeMode = StubNodeMode()
    ) async throws -> TestRuntime {
        let config = DatabaseConfiguration(
            isStoredInMemoryOnly: true,
            allowsSave: true,
            ragFactory: MockRagFactory(mockRag: rag)
        )
        let database = try Database.new(configuration: config)
        try await waitForReady(database)

        let output = BufferOutput()
        let runtime = CLIRuntime(
            database: database,
            orchestrator: MockAgentOrchestrator(),
            gateway: gateway,
            tooling: tooling,
            downloader: downloader,
            output: CLIOutput(writer: output, json: false),
            nodeMode: nodeMode
        )
        return TestRuntime(
            runtime: runtime,
            output: output,
            database: database,
            gateway: gateway,
            tooling: tooling,
            downloader: downloader,
            nodeMode: nodeMode
        )
    }
}

private func withRuntime(
    _ runtime: CLIRuntime,
    operation: () async throws -> Void
) async throws {
    let previous = CLIRuntimeProvider.factory
    CLIRuntimeProvider.factory = { _ in runtime }
    defer { CLIRuntimeProvider.factory = previous }
    try await operation()
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

private func seedChat(database: Database) async throws -> UUID {
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

private struct ModelStateReadCommand: ReadCommand {
    let id: UUID

    func execute(
        in context: ModelContext,
        userId: PersistentIdentifier?,
        rag: Ragging?
    ) throws -> Model.State? {
        let descriptor = FetchDescriptor<Model>(
            predicate: #Predicate<Model> { $0.id == id }
        )
        return try context.fetch(descriptor).first?.state
    }
}

private struct ModelProgressReadCommand: ReadCommand {
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
    private var sendResult: GatewaySendResult?

    func setSessions(_ sessions: [GatewaySession]) {
        self.sessions = sessions
    }

    func setHistory(sessionId: UUID, messages: [GatewayMessage]) {
        historyBySession[sessionId] = messages
    }

    func setSendResult(_ result: GatewaySendResult) {
        sendResult = result
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

    init(
        explorerInstance: CommunityModelsExplorerProtocol = MockCommunityModelsExplorer(),
        events: [DownloadEvent] = []
    ) {
        self.explorerInstance = explorerInstance
        self.events = events
    }

    nonisolated func download(sendableModel: SendableModel) -> AsyncThrowingStream<DownloadEvent, Error> {
        AsyncThrowingStream { continuation in
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
