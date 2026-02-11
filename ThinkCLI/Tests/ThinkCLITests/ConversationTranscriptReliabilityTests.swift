import Abstractions
import AbstractionsTestUtilities
import AgentOrchestrator
import Database
import Foundation
import Testing
@testable import ThinkCLI

@Suite("CLI Conversation Transcript Reliability", .serialized)
struct ConversationTranscriptReliabilityTests {
    @Test("20-turn conversation is stable across remote and local backends")
    @MainActor
    func twentyTurnsAcrossBackends() async throws {
        let turnCount: Int = 20

        let mlxSession = MockLLMSession()
        await mlxSession.configure(
            preload: .alreadyLoaded(),
            stream: Self.makePlainScript(turnCount: turnCount, prefix: "mlx")
        )

        let ggufSession = MockLLMSession()
        await ggufSession.configure(
            preload: .alreadyLoaded(),
            stream: Self.makePlainScript(turnCount: turnCount, prefix: "gguf")
        )

        let remoteSession = MockLLMSession()
        await remoteSession.configure(
            preload: .alreadyLoaded(),
            stream: Self.makeHarmonyScript(turnCount: turnCount, prefix: "openrouter-harmony")
                + Self.makeChatMLScript(turnCount: turnCount, prefix: "openrouter-opus")
        )

        let runtime = try await makeFullStackRuntime(
            mlxSession: mlxSession,
            ggufSession: ggufSession,
            remoteSession: remoteSession
        )

        // Build four chats:
        // 1) Remote Harmony (gpt-oss style)
        // 2) Remote ChatML (opus style)
        // 3) Local MLX
        // 4) Local GGUF
        let models = try await runtime.database.read(ModelCommands.FetchAll())

        let remoteHarmony = try #require(models.first(where: { model in
            model.backend == .remote && model.architecture == .harmony
        }))
        let remoteOpus = try #require(models.first(where: { model in
            model.backend == .remote && model.architecture == .llama
        }))
        let localMLX = try #require(models.first(where: { model in
            model.backend == .mlx && model.architecture == .llama
        }))
        let localGGUF = try #require(models.first(where: { model in
            model.backend == .gguf && model.architecture == .llama
        }))

        let chatRemoteHarmony = try await createChat(
            database: runtime.database,
            modelId: remoteHarmony.id,
            title: "remote-harmony"
        )
        let chatRemoteOpus = try await createChat(
            database: runtime.database,
            modelId: remoteOpus.id,
            title: "remote-opus"
        )
        let chatLocalMLX = try await createChat(
            database: runtime.database,
            modelId: localMLX.id,
            title: "local-mlx"
        )
        let chatLocalGGUF = try await createChat(
            database: runtime.database,
            modelId: localGGUF.id,
            title: "local-gguf"
        )

        // Execute the same 20-turn scenario against each model backend.
        try await withRuntime(runtime.runtime) {
            try await runScenario(
                runtime: runtime,
                sessionId: chatRemoteHarmony,
                turnCount: turnCount,
                expectedPrefix: "openrouter-harmony"
            )

            try await runScenario(
                runtime: runtime,
                sessionId: chatRemoteOpus,
                turnCount: turnCount,
                expectedPrefix: "openrouter-opus"
            )

            try await runScenario(
                runtime: runtime,
                sessionId: chatLocalMLX,
                turnCount: turnCount,
                expectedPrefix: "mlx"
            )

            try await runScenario(
                runtime: runtime,
                sessionId: chatLocalGGUF,
                turnCount: turnCount,
                expectedPrefix: "gguf"
            )
        }

        // Context building sanity: later turns should include earlier prompts
        // in the session inputs.
        // We only assert on a few sentinels to avoid overfitting to formatter exact output.
        let remoteContexts = await remoteSession.streamCalls.map { $0.input.context }
        #expect(remoteContexts.count >= turnCount * 2)
        if let last = remoteContexts.last {
            #expect(last.contains("U1:"))
            #expect(last.contains("U20:"))
        }
    }

    @Test("20-turn conversation with tools is stable and persists tool/final channels (remote)")
    @MainActor
    func twentyTurnsWithToolsRemote() async throws {
        let turnCount: Int = 20

        let mlxSession = MockLLMSession()
        await mlxSession.configure(preload: .alreadyLoaded(), stream: [])

        let ggufSession = MockLLMSession()
        await ggufSession.configure(preload: .alreadyLoaded(), stream: [])

        let remoteSession = MockLLMSession()
        await remoteSession.configure(
            preload: .alreadyLoaded(),
            stream: Self.makeChatMLToolUsingScript(turnCount: turnCount, prefix: "openrouter-tools")
        )

        let runtime = try await makeFullStackRuntime(
            mlxSession: mlxSession,
            ggufSession: ggufSession,
            remoteSession: remoteSession
        )

        let models = try await runtime.database.read(ModelCommands.FetchAll())
        let remoteOpus = try #require(models.first(where: { model in
            model.backend == .remote && model.architecture == .llama
        }))

        let chatRemoteTooling = try await createChat(
            database: runtime.database,
            modelId: remoteOpus.id,
            title: "remote-tools"
        )

        try await withRuntime(runtime.runtime) {
            try await runScenarioWithTools(
                runtime: runtime,
                sessionId: chatRemoteTooling,
                turnCount: turnCount,
                expectedPrefix: "openrouter-tools"
            )
        }
    }

    @Test("Mid-stream failure persists an actionable error in the final channel (CLI path)")
    @MainActor
    func midStreamFailurePersistsError() async throws {
        struct TestError: LocalizedError, Sendable {
            var errorDescription: String? { "RemoteSession.HTTPError error 0." }
        }

        let mlxSession = MockLLMSession()
        await mlxSession.configure(preload: .alreadyLoaded(), stream: [])

        let ggufSession = MockLLMSession()
        await ggufSession.configure(preload: .alreadyLoaded(), stream: [])

        let remoteSession = MockLLMSession()
        let partial = "<commentary>meta</commentary>partial output..."
        await remoteSession.configure(
            preload: .alreadyLoaded(),
            stream: [
                .init(chunks: Self.chunk(partial).map { text in
                    LLMStreamChunk(text: text, event: .text, metrics: nil)
                }, error: TestError(), delayBetweenChunks: 0)
            ]
        )

        let runtime = try await makeFullStackRuntime(
            mlxSession: mlxSession,
            ggufSession: ggufSession,
            remoteSession: remoteSession
        )

        let models = try await runtime.database.read(ModelCommands.FetchAll())
        let remoteOpus = try #require(models.first(where: { model in
            model.backend == .remote && model.architecture == .llama
        }))

        let chat = try await createChat(
            database: runtime.database,
            modelId: remoteOpus.id,
            title: "fail"
        )

        try await withRuntime(runtime.runtime) {
            await #expect(throws: Error.self) {
                try await runCLI([
                    "chat", "send",
                    "--session", chat.uuidString,
                    "--tools", "functions",
                    "--prompt",
                    "Hello"
                ])
            }
        }

        let config = try await runtime.database.read(
            ChatCommands.FetchContextData(chatId: chat)
        )
        let messages = config.contextMessages.sorted { $0.createdAt < $1.createdAt }
        #expect(messages.count == 1)

        let message = try #require(messages.first)
        let finals = message.channels.filter { $0.type == .final }
        #expect(finals.count == 1)
        let final = finals[0].content
        #expect(final.contains("**Generation failed**"))
        #expect(final.contains("RemoteSession.HTTPError"))
    }

    // MARK: - Scenario Runner

    @MainActor
    private func runScenario(
        runtime: FullStackRuntime,
        sessionId: UUID,
        turnCount: Int,
        expectedPrefix: String
    ) async throws {
        for turn in 1...turnCount {
            try await runCLI([
                "chat", "send",
                "--session", sessionId.uuidString,
                "--no-tools",
                "U\(turn): Please respond with the turn id, and keep it concise."
            ])
        }

        let history = try await runtime.gateway.history(
            sessionId: sessionId,
            options: GatewayHistoryOptions(limit: 2000)
        )

        // Expect 20 user + 20 assistant entries
        #expect(history.count == turnCount * 2)
        #expect(history.first?.role == .user)
        #expect(history.last?.role == .assistant)

        for turn in 1...turnCount {
            let expectedBase = "\(expectedPrefix) turn \(turn): ok"
            let assistant = history.first { msg in
                msg.role == .assistant && msg.content.hasPrefix(expectedBase)
            }
            #expect(assistant != nil, "Missing assistant output: \(expectedBase)")
        }

        // Database-level assertions: no duplicates, order stable, no leaked tags in final channel.
        let config = try await runtime.database.read(
            ChatCommands.FetchContextData(chatId: sessionId)
        )
        let messages = config.contextMessages.sorted { $0.createdAt < $1.createdAt }
        #expect(messages.count == turnCount)

        for message in messages {
            let finals = message.channels.filter { $0.type == .final }
            #expect(finals.count == 1)
            let final = finals[0].content
            #expect(!final.contains("<|"), "Final channel leaked Harmony tokens: \(final)")
            #expect(!final.contains("<think>"), "Final channel leaked ChatML think tag: \(final)")
            #expect(
                !final.contains("<commentary>"),
                "Final channel leaked ChatML commentary tag: \(final)"
            )
        }
    }

    @MainActor
    private func runScenarioWithTools(
        runtime: FullStackRuntime,
        sessionId: UUID,
        turnCount: Int,
        expectedPrefix: String
    ) async throws {
        for turn in 1...turnCount {
            try await runCLI([
                "chat", "send",
                "--session", sessionId.uuidString,
                "--tools", "functions",
                "--prompt",
                "U\(turn): Use tools to compute sum(turn, 1). Then answer with the sum."
            ])
        }

        let history = try await runtime.gateway.history(
            sessionId: sessionId,
            options: GatewayHistoryOptions(limit: 4000)
        )

        #expect(history.count == turnCount * 2)
        #expect(history.first?.role == .user)
        #expect(history.last?.role == .assistant)

        for turn in 1...turnCount {
            let expectedSum: Int = turn + 1
            let expectedBase = "\(expectedPrefix) turn \(turn): ok sum=\(expectedSum)"
            let assistant = history.first { msg in
                msg.role == .assistant && msg.content.hasPrefix(expectedBase)
            }
            #expect(assistant != nil, "Missing assistant output: \(expectedBase)")
        }

        let config = try await runtime.database.read(
            ChatCommands.FetchContextData(chatId: sessionId)
        )
        let messages = config.contextMessages.sorted { $0.createdAt < $1.createdAt }
        #expect(messages.count == turnCount)

        for message in messages {
            let finals = message.channels.filter { $0.type == .final }
            #expect(finals.count == 1)

            #expect(message.toolCalls.count == 1)
            #expect(message.toolCalls[0].name == "functions")

            let final = finals[0].content
            #expect(!final.contains("<tool_call>"))
            #expect(!final.contains("</tool_call>"))
            #expect(!final.contains("<commentary>"))
            #expect(!final.contains("<|"))
        }
    }

    // MARK: - Full Stack Runtime

    private struct FullStackRuntime {
        let runtime: CLIRuntime
        let output: BufferOutput
        let database: Database
        let gateway: LocalGatewayService
    }

    @MainActor
    private func makeFullStackRuntime(
        mlxSession: MockLLMSession,
        ggufSession: MockLLMSession,
        remoteSession: MockLLMSession
    ) async throws -> FullStackRuntime {
        let config = DatabaseConfiguration(
            isStoredInMemoryOnly: true,
            allowsSave: true,
            ragFactory: MockRagFactory(mockRag: MockRagging())
        )
        let database = try Database.new(configuration: config)
        try await waitForDatabaseReady(database)

        // Seed some models and a default personality/user.
        _ = try await database.write(PersonalityCommands.WriteDefault())

        let tmpDir = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
            .appendingPathComponent("think-cli-transcript-tests", isDirectory: true)
        try? FileManager.default.createDirectory(at: tmpDir, withIntermediateDirectories: true)

        let mlxPath = tmpDir.appendingPathComponent("mlx-model", isDirectory: false)
        let ggufPath = tmpDir.appendingPathComponent("gguf-model.gguf", isDirectory: false)
        let imagePath = tmpDir.appendingPathComponent("diffusion-model", isDirectory: false)
        FileManager.default.createFile(atPath: mlxPath.path, contents: Data())
        FileManager.default.createFile(atPath: ggufPath.path, contents: Data())
        FileManager.default.createFile(atPath: imagePath.path, contents: Data())

        _ = try await database.write(
            ModelCommands.CreateLocalModel(
                name: "local-mlx",
                backend: .mlx,
                type: .language,
                parameters: 1,
                ramNeeded: 1,
                size: 1,
                architecture: .llama,
                locationLocal: mlxPath.path,
                locationBookmark: nil
            )
        )
        _ = try await database.write(
            ModelCommands.CreateLocalModel(
                name: "local-gguf",
                backend: .gguf,
                type: .language,
                parameters: 1,
                ramNeeded: 1,
                size: 1,
                architecture: .llama,
                locationLocal: ggufPath.path,
                locationBookmark: nil
            )
        )

        // Chat context fetch includes diffusion configuration;
        // ensure at least one image model exists.
        _ = try await database.write(
            ModelCommands.CreateLocalModel(
                name: "local-diffusion",
                backend: .mlx,
                type: .diffusion,
                parameters: 1,
                ramNeeded: 1,
                size: 1,
                architecture: .stableDiffusion,
                locationLocal: imagePath.path,
                locationBookmark: nil
            )
        )

        _ = try await database.write(
            ModelCommands.CreateRemoteModel(
                name: "remote-harmony",
                displayName: "Remote Harmony",
                displayDescription: "OpenRouter Harmony style model",
                location: "openrouter:openai/gpt-oss-120b",
                type: .language,
                architecture: .harmony
            )
        )

        _ = try await database.write(
            ModelCommands.CreateRemoteModel(
                name: "remote-opus",
                displayName: "Remote Opus",
                displayDescription: "OpenRouter Opus style model (ChatML output)",
                location: "openrouter:anthropic/claude-3-opus",
                type: .language,
                architecture: .llama
            )
        )

        let modelDownloader = MockModelDownloader()

        let orchestrator = AgentOrchestratorFactory.make(
            database: database,
            mlxSession: mlxSession,
            ggufSession: ggufSession,
            options: .init(
                remoteSession: remoteSession,
                modelDownloader: modelDownloader,
                workspaceRoot: nil
            )
        )

        let gateway = LocalGatewayService(database: database, orchestrator: orchestrator)

        let output = BufferOutput()
        let settings = CLIRuntimeSettings(
            outputFormat: .text,
            toolAccess: .allow,
            workspaceRoot: nil,
            verbose: false
        )

        let runtime = CLIRuntime(
            database: database,
            orchestrator: orchestrator,
            gateway: gateway,
            tooling: StubTooling(),
            downloader: StubDownloader(),
            output: CLIOutput(writer: output, format: .text),
            nodeMode: StubNodeMode(),
            settings: settings
        )

        return FullStackRuntime(
            runtime: runtime,
            output: output,
            database: database,
            gateway: gateway
        )
    }

    @MainActor
    private func createChat(
        database: Database,
        modelId: UUID,
        title: String
    ) async throws -> UUID {
        let personalityId = try await database.write(
            PersonalityCommands.CreateSessionPersonality(title: title)
        )
        return try await database.write(
            ChatCommands.CreateWithModel(
                modelId: modelId,
                personalityId: personalityId
            )
        )
    }

    // MARK: - Script Builders

    private static func makeHarmonyScript(
        turnCount: Int,
        prefix: String
    ) -> [MockLLMSession.MockStreamResponse] {
        (1...turnCount).map { turn in
            let full = """
            <|start|>assistant<|channel|>analysis<|message|>plan \(turn)<|end|>\
            <|channel|>final<|message|>\(prefix) turn \(turn): ok<|end|>
            """
            return .text(Self.chunk(full), delayBetweenChunks: 0)
        }
    }

    private static func makeChatMLScript(
        turnCount: Int,
        prefix: String
    ) -> [MockLLMSession.MockStreamResponse] {
        (1...turnCount).map { turn in
            let full = """
            <think>internal \(turn)</think>
            <commentary>meta \(turn)</commentary>
            \(prefix) turn \(turn): ok<|im_end|>
            """
            return .text(Self.chunk(full), delayBetweenChunks: 0)
        }
    }

    private static func makePlainScript(
        turnCount: Int,
        prefix: String
    ) -> [MockLLMSession.MockStreamResponse] {
        (1...turnCount).map { turn in
            let full = "\(prefix) turn \(turn): ok"
            // Include a few tricky markdown cases to exercise storage and rendering invariants.
            let decorated: String = turn.isMultiple(of: 7)
                ? "\(full)\n\n```swift\nlet x = \(turn)\n```"
                : full
            return .text(Self.chunk(decorated), delayBetweenChunks: 0)
        }
    }

    private static func makeChatMLToolUsingScript(
        turnCount: Int,
        prefix: String
    ) -> [MockLLMSession.MockStreamResponse] {
        var responses: [MockLLMSession.MockStreamResponse] = []
        responses.reserveCapacity(turnCount * 2)

        for turn in 1...turnCount {
            let toolCall = """
            <commentary>tooling \(turn)</commentary>
            <tool_call>
            {"name":"functions","arguments":{
              "function_name":"calculate_sum",
              "parameters":{"a":\(turn),"b":1}
            }}
            </tool_call>
            """
            let final = "\(prefix) turn \(turn): ok sum=\(turn + 1)<|im_end|>"
            responses.append(
                .text(Self.chunk(toolCall), delayBetweenChunks: 0),
            )
            responses.append(
                .text(Self.chunk(final), delayBetweenChunks: 0)
            )
        }

        return responses
    }

    private static func chunk(_ text: String) -> [String] {
        // Deterministic chunking that intentionally splits tokens/tags across boundaries.
        let sizes: [Int] = [3, 7, 2, 5, 11, 4]
        var idx = text.startIndex
        var chunks: [String] = []
        var sizeIndex: Int = 0

        while idx < text.endIndex {
            let nextSize: Int = sizes[sizeIndex % sizes.count]
            sizeIndex += 1
            let end = text.index(idx, offsetBy: nextSize, limitedBy: text.endIndex)
                ?? text.endIndex
            chunks.append(String(text[idx..<end]))
            idx = end
        }
        return chunks
    }
}

// MARK: - Test Extensions

extension MockLLMSession {
    fileprivate func configure(
        preload: MockPreloadResponse,
        stream: [MockStreamResponse]
    ) async {
        preloadResponse = preload
        sequentialStreamResponses = stream
    }
}

@MainActor
private func waitForDatabaseReady(
    _ database: Database,
    timeout: TimeInterval = 2.0
) async throws {
    let deadline: Date = Date().addingTimeInterval(timeout)
    while Date() < deadline {
        if database.status == .ready {
            return
        }
        try await Task.sleep(nanoseconds: 50_000_000)
    }
    throw DatabaseError.databaseNotReady
}
