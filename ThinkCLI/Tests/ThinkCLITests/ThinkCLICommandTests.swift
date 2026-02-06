import Abstractions
import ArgumentParser
import AbstractionsTestUtilities
import Database
import Foundation
import SwiftData
import Testing
import ViewModels
@testable import ThinkCLI

@Suite("ThinkCLI Command Tests", .serialized)
struct ThinkCLICommandTests {
    @Test("Gateway start/stop and status")
    func gatewayStartStop() async throws {
        let context = try await TestRuntime.make()
        try await withRuntime(context.runtime) {
            let start = try GatewayCommand.Start.parse([
                "--port", "9876",
                "--once"
            ])
            try await runCommand(start)

            let status = try GatewayCommand.Status.parse([])
            try await runCommand(status)
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
            let list = try ChatCommand.List.parse([])
            try await runCommand(list)

            let get = try ChatCommand.Get.parse([session.id.uuidString])
            try await runCommand(get)

            let history = try ChatCommand.History.parse([
                "--session", session.id.uuidString,
                "--limit", "10"
            ])
            try await runCommand(history)

            let send = try ChatCommand.Send.parse([
                "--session", session.id.uuidString,
                "--no-stream",
                "Hello"
            ])
            try await runCommand(send)
        }

        #expect(context.output.lines.contains { $0.contains("Test Chat") })
        #expect(context.output.lines.contains { $0.contains("Response") })
    }

    @Test("Chat send streams output tokens")
    func chatSendStreamsOutput() async throws {
        let orchestrator = MockAgentOrchestrator()
        let gateway = StubGateway()
        await gateway.setSendDelayNanoseconds(200_000_000)
        await gateway.setSendResult(
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
        let context = try await TestRuntime.make(
            gateway: gateway,
            orchestrator: orchestrator
        )
        let sessionId = UUID()
        let runId = UUID()

        try await withRuntime(context.runtime) {
            let send = try ChatCommand.Send.parse([
                "--session", sessionId.uuidString,
                "Hello"
            ])

            let sendTask = Task {
                try await runCommand(send)
            }

            await Task.yield()
            await orchestrator.emitEvent(.generationStarted(runId: runId))
            await orchestrator.emitEvent(.textDelta(text: "Hello"))
            await orchestrator.emitEvent(.textDelta(text: " world"))
            await orchestrator.emitEvent(.generationCompleted(runId: runId, totalDurationMs: 1))
            try await sendTask.value
        }

        let streamed = context.output.inline.joined()
        #expect(streamed.contains("Hello world"))
        #expect(context.output.lines.contains { $0.contains("Response") } == false)
    }

    @Test("Chat send defaults to tool policy when no tools are provided")
    @MainActor
    func chatSendDefaultsToToolPolicy() async throws {
        let context = try await TestRuntime.make()
        let chatId = try await seedChat(database: context.database)
        await context.tooling.setDefinitions([
            ToolDefinition(name: "memory", description: "Memory", schema: "{}")
        ])
        _ = try await context.database.write(
            ToolPolicyCommands.UpsertForChat(
                chatId: chatId,
                profile: .minimal,
                allowList: [ToolIdentifier.memory.toolName]
            )
        )

        try await withRuntime(context.runtime) {
            let send = try ChatCommand.Send.parse([
                "--session", chatId.uuidString,
                "--no-stream",
                "Remember this."
            ])
            try await runCommand(send)
        }

        let options = await context.gateway.lastSendOptions
        let action = try #require(options?.action)
        #expect(action.tools == Set<ToolIdentifier>([.memory]))
    }

    @Test("Chat send --no-tools overrides tool policy defaults")
    @MainActor
    func chatSendNoToolsOverridesPolicy() async throws {
        let context = try await TestRuntime.make()
        let chatId = try await seedChat(database: context.database)
        _ = try await context.database.write(
            ToolPolicyCommands.UpsertForChat(
                chatId: chatId,
                profile: .research
            )
        )

        try await withRuntime(context.runtime) {
            let send = try ChatCommand.Send.parse([
                "--session", chatId.uuidString,
                "--no-tools",
                "--no-stream",
                "No tools."
            ])
            try await runCommand(send)
        }

        let options = await context.gateway.lastSendOptions
        let action = try #require(options?.action)
        #expect(action.tools.isEmpty)
    }


    @Test("Chat rename/delete uses database")
    @MainActor
    func chatRenameDelete() async throws {
        let context = try await TestRuntime.make()
        let chatId = try await seedChat(database: context.database)

        try await withRuntime(context.runtime) {
            let rename = try ChatCommand.Rename.parse([
                "--session", chatId.uuidString,
                "Renamed"
            ])
            try await runCommand(rename)

            let delete = try ChatCommand.Delete.parse([
                "--session", chatId.uuidString
            ])
            try await runCommand(delete)
        }

        await #expect(throws: DatabaseError.chatNotFound) {
            _ = try await context.database.read(ChatCommands.FetchGatewaySession(chatId: chatId))
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
            let list = try ModelsCommand.List.parse([])
            try await runCommand(list)

            let info = try ModelsCommand.Info.parse([modelId.uuidString])
            try await runCommand(info)

            let remove = try ModelsCommand.Remove.parse([modelId.uuidString])
            try await runCommand(remove)
        }

        await #expect(throws: DatabaseError.modelNotFound) {
            _ = try await context.database.read(ModelCommands.GetSendableModel(id: modelId))
        }
    }

    @Test("Models download updates progress")
    @MainActor
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
            let download = try ModelsCommand.Download.parse([discovered.id])
            try await runCommand(download)
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
            let list = try ToolsCommand.List.parse([])
            try await runCommand(list)

            let run = try ToolsCommand.Run.parse([
                "browser.search",
                "--args", "{\"q\":\"swift\"}"
            ])
            try await runCommand(run)
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
            let index = try RagCommand.Index.parse([
                "--table", table,
                "--text", "hello world"
            ])
            try await runCommand(index)

            let search = try RagCommand.Search.parse([
                "--table", table,
                "--query", "hello"
            ])
            try await runCommand(search)

            let delete = try RagCommand.Delete.parse([
                "--table", table,
                UUID().uuidString
            ])
            try await runCommand(delete)
        }

        let addCalls = await mockRag.addTextCalls
        #expect(addCalls.isEmpty == false)
    }

    @Test("Skills list/enable/disable")
    @MainActor
    func skillsCommands() async throws {
        let context = try await TestRuntime.make()

        try await withRuntime(context.runtime) {
            let create = try SkillsCommand.Create.parse([
                "--name", "Test Skill",
                "--description", "desc",
                "--instructions", "do it",
                "--tools", "browser.search"
            ])
            try await runCommand(create)

            let list = try SkillsCommand.List.parse([])
            try await runCommand(list)
        }

        let skills = try await context.database.read(SkillCommands.GetAll())
        let skillId = try #require(skills.first?.id)

        try await withRuntime(context.runtime) {
            let enable = try SkillsCommand.Enable.parse([skillId.uuidString])
            try await runCommand(enable)

            let disable = try SkillsCommand.Disable.parse([skillId.uuidString])
            try await runCommand(disable)
        }

        let skill = try await context.database.read(SkillCommands.Read(skillId: skillId))
        #expect(skill.isEnabled == false)
    }

    @Test("Personalities list/create/chat/update/delete")
    @MainActor
    func personalityCommands() async throws {
        let context = try await TestRuntime.make()
        _ = try await seedChat(database: context.database)

        try await withRuntime(context.runtime) {
            let list = try PersonalityCommand.List.parse([])
            try await runCommand(list)

            let create = try PersonalityCommand.Create.parse([
                "--name", "Ari",
                "--description", "Coach",
                "--instructions", "Be concise and practical."
            ])
            try await runCommand(create)
        }

        let personalities = try await context.database.read(PersonalityCommands.GetAll())
        let custom = try #require(personalities.first { $0.name == "Ari" })

        try await withRuntime(context.runtime) {
            let chat = try PersonalityCommand.Chat.parse([custom.id.uuidString])
            try await runCommand(chat)

            let update = try PersonalityCommand.Update.parse([
                custom.id.uuidString,
                "--name", "Ari Updated"
            ])
            try await runCommand(update)
        }

        let updated = try await context.database.read(
            PersonalityCommands.Read(personalityId: custom.id)
        )
        #expect(updated.name == "Ari Updated")
        #expect(updated.chat != nil)

        try await withRuntime(context.runtime) {
            let delete = try PersonalityCommand.Delete.parse([custom.id.uuidString])
            try await runCommand(delete)
        }

        await #expect(throws: DatabaseError.personalityNotFound) {
            _ = try await context.database.read(PersonalityCommands.Read(personalityId: custom.id))
        }
    }


    @Test("Schedules create/update/enable/disable/delete")
    @MainActor
    func schedulesCommands() async throws {
        let context = try await TestRuntime.make()
        let cronExpression = "0 0 * * *"

        try await withRuntime(context.runtime) {
            let create = try SchedulesCommand.Create.parse([
                "--title", "Daily",
                "--prompt", "Run",
                "--cron", cronExpression,
                "--kind", "cron",
                "--action", "text"
            ])
            try await runCommand(create)

            let list = try SchedulesCommand.List.parse([])
            try await runCommand(list)
        }

        let schedules = try await context.database.read(AutomationScheduleCommands.List())
        let scheduleId = try #require(schedules.first?.id)

        try await withRuntime(context.runtime) {
            let update = try SchedulesCommand.Update.parse([
                scheduleId.uuidString,
                "--title", "Updated"
            ])
            try await runCommand(update)

            let enable = try SchedulesCommand.Enable.parse([scheduleId.uuidString])
            try await runCommand(enable)

            let disable = try SchedulesCommand.Disable.parse([scheduleId.uuidString])
            try await runCommand(disable)

            let delete = try SchedulesCommand.Delete.parse([scheduleId.uuidString])
            try await runCommand(delete)
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
    let orchestrator: MockAgentOrchestrator

    static func make(
        rag: MockRagging = MockRagging(),
        gateway: StubGateway = StubGateway(),
        tooling: StubTooling = StubTooling(),
        downloader: StubDownloader = StubDownloader(),
        nodeMode: StubNodeMode = StubNodeMode(),
        orchestrator: MockAgentOrchestrator = MockAgentOrchestrator()
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
            orchestrator: orchestrator,
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
            nodeMode: nodeMode,
            orchestrator: orchestrator
        )
    }
}

@MainActor
private func withRuntime(
    _ runtime: CLIRuntime,
    operation: () async throws -> Void
) async throws {
    let previous = await CLIRuntimeProvider.getFactory()
    await CLIRuntimeProvider.setFactory({ _ in runtime })
    do {
        try await operation()
        await CLIRuntimeProvider.setFactory(previous)
    } catch {
        await CLIRuntimeProvider.setFactory(previous)
        throw error
    }
}

private func runCommand<C: AsyncParsableCommand>(_ command: C) async throws {
    var mutable = command
    try await mutable.run()
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
