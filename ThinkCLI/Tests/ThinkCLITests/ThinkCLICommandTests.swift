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
            try await runCLI([
                "gateway", "start",
                "--port", "9876",
                "--once"
            ])

            try await runCLI(["gateway", "status"])
        }

        let running = await context.nodeMode.status()
        #expect(running == false)
        #expect(context.output.lines.contains { $0.contains("Gateway server running") })
    }

    @Test("OpenClaw add/list/use/delete stores token in secure storage")
    func openClawCommands() async throws {
        let context = try await TestRuntime.make()
        let storage = InMemorySecureStorage()

        try await withRuntime(context.runtime, operation: {
            try await OpenClawSecureStorageProvider.withFactory({ storage }, operation: {
                try await runCLI([
                    "openclaw", "upsert",
                    "--name", "Test Gateway",
                    "--url", "ws://example.invalid:18789",
                    "--token", "token-123",
                    "--activate"
                ])

                try await runCLI(["openclaw", "list"])

                let instances = try await context.database.read(
                    SettingsCommands.FetchOpenClawInstances()
                )
                #expect(instances.count == 1)
                let id = instances[0].id

                let key = "openclaw.instance.\(id.uuidString).shared_token"
                let stored = try await storage.retrieve(forKey: key)
                #expect(String(data: stored ?? Data(), encoding: .utf8) == "token-123")

                try await runCLI(["openclaw", "use", "--id", id.uuidString])
                try await runCLI(["openclaw", "delete", "--id", id.uuidString])
            })
        })

        #expect(context.output.lines.contains { $0.contains("OpenClaw instance saved") })
        #expect(context.output.lines.contains { $0.contains("Test Gateway") })
        #expect(context.output.lines.contains { $0.contains("Active OpenClaw instance set") })
        #expect(context.output.lines.contains { $0.contains("OpenClaw instance deleted") })
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
            try await runCLI(["chat", "list"])

            try await runCLI(["chat", "get", session.id.uuidString])

            try await runCLI([
                "chat", "history",
                "--session", session.id.uuidString,
                "--limit", "10"
            ])

            try await runCLI([
                "chat", "send",
                "--session", session.id.uuidString,
                "--no-stream",
                "Hello"
            ])
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
            let sendTask = Task {
                try await runCLI([
                    "chat", "send",
                    "--session", sessionId.uuidString,
                    "Hello"
                ])
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

    @Test("Chat send streams JSON lines output")
    func chatSendStreamsJsonLinesOutput() async throws {
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
            orchestrator: orchestrator,
            outputFormat: .jsonLines
        )
        let sessionId = UUID()
        let runId = UUID()

        try await withRuntime(context.runtime) {
            let sendTask = Task {
                try await runCLI([
                    "chat", "send",
                    "--session", sessionId.uuidString,
                    "Hello"
                ])
            }

            await Task.yield()
            await orchestrator.emitEvent(.generationStarted(runId: runId))
            await orchestrator.emitEvent(.textDelta(text: "Hello"))
            await orchestrator.emitEvent(.textDelta(text: " json"))
            await orchestrator.emitEvent(.generationCompleted(runId: runId, totalDurationMs: 1))
            try await sendTask.value
        }

        #expect(context.output.inline.isEmpty)
        #expect(context.output.lines.contains { $0.contains("\"type\":\"stream\"") })
    }

    @Test("Chat send emits heartbeat JSON lines when --no-stream and heartbeat enabled")
    func chatSendEmitsHeartbeatsJsonLinesNoStream() async throws {
        let gateway = StubGateway()
        // Delay long enough to ensure at least one heartbeat at 1s.
        await gateway.setSendDelayNanoseconds(1_500_000_000)
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
            outputFormat: .jsonLines
        )
        let sessionId = UUID()

        try await withRuntime(context.runtime) {
            try await runCLI([
                "chat", "send",
                "--session", sessionId.uuidString,
                "--no-stream",
                "--heartbeat-seconds", "1",
                "Hello"
            ])
        }

        // Should include heartbeat lines while waiting for send to complete.
        #expect(context.output.lines.contains { $0.contains("\"type\":\"heartbeat\"") })
        // Final result should still be emitted.
        #expect(context.output.lines.contains { $0.contains("\"messageId\"") })
    }

    @Test("Chat send respects --timeout-seconds")
    func chatSendTimeout() async throws {
        let gateway = StubGateway()
        // Delay longer than timeout.
        await gateway.setSendDelayNanoseconds(2_000_000_000)
        let context = try await TestRuntime.make(
            gateway: gateway,
            outputFormat: .jsonLines
        )
        let sessionId = UUID()

        do {
            try await withRuntime(context.runtime) {
                try await runCLI([
                    "chat", "send",
                    "--session", sessionId.uuidString,
                    "--no-stream",
                    "--heartbeat-seconds", "1",
                    "--timeout-seconds", "1",
                    "Hello"
                ])
            }
            #expect(Bool(false), "Expected a timeout error.")
        } catch let err as CLIError {
            #expect(err.message.contains("Timed out during chat send"))
            #expect(err.exitCode == .unavailable)
        }
    }

    @Test("Chat stop calls orchestrator stop")
    func chatStopCallsOrchestrator() async throws {
        let orchestrator = MockAgentOrchestrator()
        let context = try await TestRuntime.make(orchestrator: orchestrator)
        let sessionId = UUID()

        try await withRuntime(context.runtime) {
            try await runCLI([
                "chat", "stop",
                "--session", sessionId.uuidString
            ])
        }

        let stopCount = await orchestrator.stopCalls.count
        #expect(stopCount == 1)
        #expect(context.output.lines.contains { $0.contains("Stop requested") })
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
            try await runCLI([
                "chat", "send",
                "--session", chatId.uuidString,
                "--no-stream",
                "Remember this."
            ])
        }

        let options = await context.gateway.lastSendOptions
        let action = try #require(options?.action)
        #expect(action.tools == Set<ToolIdentifier>([.memory]))
    }

    @Test("Chat send accepts --prompt")
    @MainActor
    func chatSendPromptOption() async throws {
        let context = try await TestRuntime.make()
        let chatId = try await seedChat(database: context.database)

        try await withRuntime(context.runtime) {
            try await runCLI([
                "chat", "send",
                "--session", chatId.uuidString,
                "--prompt", "Hello from option",
                "--no-stream"
            ])
        }

        let options = await context.gateway.lastSendOptions
        #expect(options != nil)
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
            try await runCLI([
                "chat", "send",
                "--session", chatId.uuidString,
                "--no-tools",
                "--no-stream",
                "No tools."
            ])
        }

        let options = await context.gateway.lastSendOptions
        let action = try #require(options?.action)
        #expect(action.tools.isEmpty)
    }

    @Test("Chat send denies tools when tool access disabled")
    @MainActor
    func chatSendToolsDeniedWhenToolAccessDisabled() async throws {
        let context = try await TestRuntime.make(toolAccess: .deny)
        let chatId = try await seedChat(database: context.database)

        await #expect(throws: CLIError.self) {
            try await withRuntime(context.runtime) {
                try await runCLI([
                    "chat", "send",
                    "--session", chatId.uuidString,
                    "--tools", "memory",
                    "--no-stream",
                    "Hello"
                ])
            }
        }
    }


    @Test("Chat rename/delete uses database")
    @MainActor
    func chatRenameDelete() async throws {
        let context = try await TestRuntime.make()
        let chatId = try await seedChat(database: context.database)

        try await withRuntime(context.runtime) {
            try await runCLI([
                "chat", "rename",
                "--session", chatId.uuidString,
                "Renamed"
            ])

            try await runCLI([
                "chat", "delete",
                "--session", chatId.uuidString
            ])
        }

        await #expect(throws: DatabaseError.chatNotFound) {
            _ = try await context.database.read(ChatCommands.FetchGatewaySession(chatId: chatId))
        }
    }

        @Test("Chat create seeds image model when only language model exists")
    @MainActor
    func chatCreateSeedsImageModel() async throws {
        let context = try await TestRuntime.make()
        _ = try await context.database.write(
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

        let modelsBefore = try await context.database.read(ModelCommands.FetchAll())
        let hadImageModel = modelsBefore.contains { model in
            model.modelType == .diffusion || model.modelType == .diffusionXL
        }
        #expect(hadImageModel == false)

        try await withRuntime(context.runtime) {
            try await runCLI(["chat", "create"])
        }

        let chats = try await context.database.read(ChatCommands.GetAll())
        let chat = try #require(chats.first)
        #expect(chat.imageModel.type == .diffusion || chat.imageModel.type == .diffusionXL)
    }

    @Test("Models list/info/add/remove")
    @MainActor
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
            try await runCLI(["models", "list"])

            try await runCLI(["models", "info", modelId.uuidString])

            let chats = try await context.database.read(ChatCommands.GetAll())
            for chat in chats {
                _ = try await context.database.write(ChatCommands.Delete(id: chat.id))
            }

            try await runCLI(["models", "remove", modelId.uuidString])
        }

        await #expect(throws: DatabaseError.modelNotFound) {
            _ = try await context.database.read(ModelCommands.GetSendableModel(id: modelId))
        }
    }


    @Test("Models add-remote defaults to GPT architecture for language models")
    @MainActor
    func modelAddRemoteDefaultsArchitecture() async throws {
        let context = try await TestRuntime.make()

        try await withRuntime(context.runtime) {
            try await runCLI([
                "models", "add-remote",
                "--name", "OpenRouter Sonnet",
                "--location", "openrouter:anthropic/claude-3.5-sonnet"
            ])
        }

        let models = try await context.database.read(ModelCommands.FetchAll())
        let remoteModel = try #require(models.first { model in
            model.locationKind == .remote &&
                model.location == "openrouter:anthropic/claude-3.5-sonnet"
        })

        #expect(remoteModel.architecture == .gpt)
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
            try await runCLI(["models", "download", discovered.id])
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
            try await runCLI(["tools", "list"])

            try await runCLI([
                "tools", "run",
                "browser.search",
                "--args", "{\"q\":\"swift\"}"
            ])
        }

        let requests = await tooling.lastRequests()
        #expect(requests.first?.name == "browser.search")
    }

    @Test("Tools run denied when tool access disabled")
    func toolsRunDeniedWhenToolAccessDisabled() async throws {
        let context = try await TestRuntime.make(toolAccess: .deny)

        await #expect(throws: CLIError.self) {
            try await withRuntime(context.runtime) {
                try await runCLI([
                    "tools", "run",
                    "browser.search",
                    "--args", "{}"
                ])
            }
        }
    }

    @Test("RAG index/search/delete")
    func ragCommands() async throws {
        let mockRag = MockRagging(searchResults: [
            SearchResult(id: UUID(), text: "hello", keywords: "hello", score: 0.1, rowId: 0)
        ])
        let context = try await TestRuntime.make(rag: mockRag)
        let table = RagTableName.chatTableName(chatId: UUID())

        try await withRuntime(context.runtime) {
            try await runCLI([
                "rag", "index",
                "--table", table,
                "--text", "hello world"
            ])

            try await runCLI([
                "rag", "search",
                "--table", table,
                "--query", "hello"
            ])

            try await runCLI([
                "rag", "delete",
                "--table", table,
                UUID().uuidString
            ])
        }

        let addCalls = await mockRag.addTextCalls
        #expect(addCalls.isEmpty == false)
    }

    @Test("Skills list/enable/disable")
    @MainActor
    func skillsCommands() async throws {
        let context = try await TestRuntime.make()

        try await withRuntime(context.runtime) {
            try await runCLI([
                "skills", "create",
                "--name", "Test Skill",
                "--description", "desc",
                "--instructions", "do it",
                "--tools", "browser.search"
            ])

            try await runCLI(["skills", "list"])
        }

        let skills = try await context.database.read(SkillCommands.GetAll())
        let skillId = try #require(skills.first?.id)

        try await withRuntime(context.runtime) {
            try await runCLI(["skills", "enable", skillId.uuidString])

            try await runCLI(["skills", "disable", skillId.uuidString])
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
            try await runCLI(["personality", "list"])

            try await runCLI([
                "personality", "create",
                "--name", "Ari",
                "--description", "Coach",
                "--instructions", "Be concise and practical."
            ])
        }

        let personalities = try await context.database.read(PersonalityCommands.GetAll())
        let custom = try #require(personalities.first { $0.name == "Ari" })

        try await withRuntime(context.runtime) {
            try await runCLI(["personality", "chat", custom.id.uuidString])

            try await runCLI([
                "personality", "update",
                custom.id.uuidString,
                "--name", "Ari Updated"
            ])
        }

        let updated = try await context.database.read(
            PersonalityCommands.Read(personalityId: custom.id)
        )
        #expect(updated.name == "Ari Updated")
        #expect(updated.chat != nil)

        try await withRuntime(context.runtime) {
            try await runCLI(["personality", "delete", custom.id.uuidString])
        }

        await #expect(throws: DatabaseError.personalityNotFound) {
            _ = try await context.database.read(PersonalityCommands.Read(personalityId: custom.id))
        }
    }


    @Test("Global options merge from root and subcommand")
    func globalOptionsMerge() throws {
        let command = try ThinkCLI.parseAsRoot([
            "--store", "root.store",
            "--workspace", "/tmp/work",
            "--format", "json-lines",
            "--tool-access", "deny",
            "chat", "list"
        ])
        let list = try #require(command as? ChatCommand.List)
        #expect(list.resolvedGlobal.store == "root.store")
        #expect(list.resolvedGlobal.workspace == "/tmp/work")
        #expect(list.resolvedGlobal.resolvedOutputFormat == .jsonLines)
        #expect(list.resolvedGlobal.resolvedToolAccess == .deny)

        let override = try ThinkCLI.parseAsRoot([
            "--store", "root.store",
            "--format", "json-lines",
            "--tool-access", "deny",
            "chat", "list",
            "--store", "child.store",
            "--format", "json",
            "--tool-access", "allow"
        ])
        let listOverride = try #require(override as? ChatCommand.List)
        #expect(listOverride.resolvedGlobal.store == "child.store")
        #expect(listOverride.resolvedGlobal.resolvedOutputFormat == .json)
        #expect(listOverride.resolvedGlobal.resolvedToolAccess == .allow)
    }

    @Test("Onboard command parses workspace-path without conflicts")
    func onboardCommandParsesWorkspacePath() throws {
        let command = try ThinkCLI.parseAsRoot([
            "onboard",
            "--workspace-path", "/tmp/onboard",
            "--non-interactive",
            "--skip-download"
        ])
        let onboard = try #require(command as? OnboardCommand)
        #expect(onboard.workspacePath == "/tmp/onboard")
    }

    @Test("Status command reports counts")
    func statusCommand() async throws {
        let context = try await TestRuntime.make()
        _ = try await seedChat(database: context.database)

        try await withRuntime(context.runtime) {
            try await runCLI(["status"])
        }

        let output = context.output.lines.joined(separator: "\n")
        #expect(output.contains("store="))
        #expect(output.contains("models="))
    }

    @Test("Doctor command reports checks")
    func doctorCommand() async throws {
        let context = try await TestRuntime.make()

        try await withRuntime(context.runtime) {
            try await runCLI(["doctor"])
        }

        let output = context.output.lines.joined(separator: "\n")
        #expect(output.contains("config"))
        #expect(output.contains("["))
    }

    @Test("Config command persists workspace and reset")
    func configCommandPersists() async throws {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        let configURL = tempDir.appendingPathComponent("config.json")
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)

        setenv(CLIConfigStore.overrideEnvKey, configURL.path, 1)
        defer {
            unsetenv(CLIConfigStore.overrideEnvKey)
            try? FileManager.default.removeItem(at: tempDir)
        }

        try await runCLI(["config", "set", "--workspace-path", tempDir.path])
        let store = CLIConfigStore()
        let config = try store.load()
        #expect(config.workspacePath == tempDir.path)

        try await runCLI(["config", "reset"])
        #expect(store.exists() == false)
    }

    @Test("Config resolver reports sources")
    func configResolverReportsSources() throws {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        let configURL = tempDir.appendingPathComponent("config.json")
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let store = CLIConfigStore(url: configURL)
        var config = CLIConfig()
        let modelId = UUID()
        config.workspacePath = "/tmp/config-workspace"
        config.defaultModelId = modelId
        config.preferredSkills = ["skill-a"]
        try store.save(config)

        var options = GlobalOptions()
        options.workspace = "/tmp/cli-workspace"
        options.format = .jsonLines
        options.toolAccess = .deny
        options.store = "custom.store"
        options.verbose = true

        let resolver = CLIConfigResolver(
            configStore: store,
            environment: [CLIConfigStore.overrideEnvKey: configURL.path]
        )
        let resolved = resolver.resolve(options: options)

        #expect(resolved.configPath.value == configURL.path)
        #expect(resolved.configPath.source == .environment)
        #expect(resolved.workspacePath.value == "/tmp/cli-workspace")
        #expect(resolved.workspacePath.source == .cli)
        #expect(resolved.defaultModelId.value == modelId)
        #expect(resolved.defaultModelId.source == .configFile)
        #expect(resolved.preferredSkills.value == ["skill-a"])
        #expect(resolved.preferredSkills.source == .configFile)
        #expect(resolved.outputFormat.value == .jsonLines)
        #expect(resolved.outputFormat.source == .cli)
        #expect(resolved.toolAccess.value == .deny)
        #expect(resolved.toolAccess.source == .cli)
        #expect(resolved.store.value == "custom.store")
        #expect(resolved.store.source == .cli)
        #expect(resolved.verbose.value == true)
        #expect(resolved.verbose.source == .cli)
    }

    @Test("Onboarding persists workspace, model, and skills")
    func onboardingPersistsSelections() async throws {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        let configURL = tempDir.appendingPathComponent("config.json")
        let store = CLIConfigStore(url: configURL)
        let context = try await TestRuntime.make()

        let modelId = try await context.database.write(
            ModelCommands.CreateLocalModel(
                name: "Onboard Model",
                backend: .mlx,
                type: .language,
                parameters: 1,
                ramNeeded: 1,
                size: 1,
                architecture: .llama,
                locationLocal: "/tmp/onboard",
                locationBookmark: nil
            )
        )

        let skillId = try await context.database.write(
            SkillCommands.Create(
                name: "Test Skill",
                skillDescription: "desc",
                instructions: "do it",
                tools: ["browser.search"],
                isEnabled: false
            )
        )

        let onboarding = CLIOnboarding(
            configStore: store,
            dateProvider: { Date(timeIntervalSince1970: 0) }
        )
        let options = CLIOnboarding.Options(
            workspace: tempDir.path,
            model: modelId.uuidString,
            preferredBackend: nil,
            skipDownload: true,
            skills: ["Test Skill"]
        )

        let result = try await onboarding.run(runtime: context.runtime, options: options)
        let saved = try store.load()

        #expect(saved.workspacePath == tempDir.path)
        #expect(saved.defaultModelId == modelId)
        #expect(saved.preferredSkills == ["Test Skill"])
        #expect(result.enabledSkillIds.contains(skillId))

        let skillIsEnabled = try await Task { @MainActor in
            let skill = try await context.database.read(SkillCommands.Read(skillId: skillId))
            return skill.isEnabled
        }.value
        #expect(skillIsEnabled == true)
    }

    @Test("Onboarding step creates workspace directory")
    func onboardingWorkspaceCreatesDirectory() throws {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        let workspacePath = tempDir.appendingPathComponent("workspace").path
        let onboarding = CLIOnboarding(fileManager: FileManager.default)

        let updated = try onboarding.applyWorkspace(workspacePath, config: CLIConfig())
        var isDirectory: ObjCBool = false
        let exists = FileManager.default.fileExists(
            atPath: workspacePath,
            isDirectory: &isDirectory
        )

        #expect(exists == true)
        #expect(isDirectory.boolValue == true)
        #expect(updated.workspacePath == workspacePath)
    }

    @Test("Onboarding step rejects unknown skills")
    func onboardingSkillValidation() async throws {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        let store = CLIConfigStore(url: tempDir.appendingPathComponent("config.json"))
        let context = try await TestRuntime.make()
        let onboarding = CLIOnboarding(configStore: store)

        await #expect(throws: ValidationError.self) {
            _ = try await onboarding.applySkills(
                ["Missing Skill"],
                runtime: context.runtime,
                config: CLIConfig()
            )
        }
    }

    @Test("Onboarding downloads model when repo provided")
    @MainActor
    func onboardingDownloadsModel() async throws {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        let configURL = tempDir.appendingPathComponent("config.json")
        let store = CLIConfigStore(url: configURL)

        let explorer = MockCommunityModelsExplorer()
        let discovered = DiscoveredModel.createMock(
            id: "mlx-community/onboard-model",
            detectedBackends: [.mlx]
        )
        explorer.discoverModelResponses[discovered.id] = discovered

        let sendable = SendableModel(
            id: UUID(),
            ramNeeded: 1,
            modelType: .language,
            location: discovered.id,
            architecture: .llama,
            backend: .mlx,
            locationKind: .huggingFace
        )
        explorer.prepareForDownloadResult = sendable

        let modelInfo = ModelInfo(
            id: sendable.id,
            name: "Onboard",
            backend: sendable.backend,
            location: URL(fileURLWithPath: "/tmp/\(sendable.location)"),
            totalSize: 1,
            downloadDate: Date()
        )

        let downloader = StubDownloader(
            explorerInstance: explorer,
            events: [.completed(modelInfo)]
        )
        let context = try await TestRuntime.make(downloader: downloader)

        let onboarding = CLIOnboarding(configStore: store)
        let options = CLIOnboarding.Options(
            workspace: nil,
            model: discovered.id,
            preferredBackend: nil,
            skipDownload: false,
            skills: []
        )

        let result = try await onboarding.run(runtime: context.runtime, options: options)
        let downloaded = await downloader.lastDownloaded()

        #expect(downloaded?.id == sendable.id)
        #expect(result.defaultModelId == sendable.id)
    }

    @Test("Schedules create/update/enable/disable/delete")
    @MainActor
    func schedulesCommands() async throws {
        let context = try await TestRuntime.make()
        let cronExpression = "0 0 * * *"

        try await withRuntime(context.runtime) {
            try await runCLI([
                "schedules", "create",
                "--title", "Daily",
                "--prompt", "Run",
                "--cron", cronExpression,
                "--kind", "cron",
                "--action", "text"
            ])

            try await runCLI(["schedules", "list"])
        }

        let schedules = try await context.database.read(AutomationScheduleCommands.List())
        let scheduleId = try #require(schedules.first?.id)

        try await withRuntime(context.runtime) {
            try await runCLI([
                "schedules", "update",
                scheduleId.uuidString,
                "--title", "Updated"
            ])

            try await runCLI(["schedules", "enable", scheduleId.uuidString])

            try await runCLI(["schedules", "disable", scheduleId.uuidString])

            try await runCLI(["schedules", "delete", scheduleId.uuidString])
        }

        let remaining = try await context.database.read(AutomationScheduleCommands.List())
        #expect(remaining.isEmpty)
    }
}
