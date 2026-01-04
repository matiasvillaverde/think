import Abstractions
import ArgumentParser
import Database
import Foundation

struct ChatCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "chat",
        abstract: "Manage chat sessions and messages.",
        subcommands: [
            List.self,
            Create.self,
            Get.self,
            Send.self,
            History.self,
            Rename.self,
            Delete.self
        ]
    )

    @OptionGroup
    var global: GlobalOptions
}

extension ChatCommand {
    struct List: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            abstract: "List chat sessions."
        )

        @OptionGroup
        var global: GlobalOptions

        func run() async throws {
            let runtime = try await CLIRuntimeProvider.runtime(for: global)
            let sessions = try await runtime.gateway.listSessions()
            let fallback = sessions.isEmpty
                ? "No sessions."
                : sessions.map { "\($0.id.uuidString)  \($0.title)" }.joined(separator: "\n")
            runtime.output.emit(sessions, fallback: fallback)
        }
    }

    struct Create: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            abstract: "Create a new chat session."
        )

        @OptionGroup
        var global: GlobalOptions

        @Option(name: .long, help: "Optional title for the session.")
        var title: String?

        func run() async throws {
            let runtime = try await CLIRuntimeProvider.runtime(for: global)
            let session = try await runtime.gateway.createSession(title: title)
            let fallback = "Created session \(session.id.uuidString)"
            runtime.output.emit(session, fallback: fallback)
        }
    }

    struct Get: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            abstract: "Fetch a chat session by id."
        )

        @OptionGroup
        var global: GlobalOptions

        @Argument(help: "Session UUID.")
        var id: String

        func run() async throws {
            let runtime = try await CLIRuntimeProvider.runtime(for: global)
            let sessionId = try CLIParsing.parseUUID(id, field: "session")
            let session = try await runtime.gateway.getSession(id: sessionId)
            let fallback = "\(session.id.uuidString)  \(session.title)"
            runtime.output.emit(session, fallback: fallback)
        }
    }

    struct Send: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            abstract: "Send a prompt to a chat session."
        )

        @OptionGroup
        var global: GlobalOptions

        @Option(name: .long, help: "Session UUID.")
        var session: String

        @Argument(help: "Prompt to send.")
        var input: String

        @Option(name: .long, parsing: .upToNextOption, help: "Tools to enable.")
        var tools: [String] = []

        @Flag(name: .long, help: "Use image generation action.")
        var image: Bool = false

        @Flag(
            name: .long,
            inversion: .prefixedNo,
            help: "Stream output as it is generated."
        )
        var stream: Bool = true

        func run() async throws {
            let runtime = try await CLIRuntimeProvider.runtime(for: global)
            let sessionId = try CLIParsing.parseUUID(session, field: "session")
            let identifiers = try CLIParsing.parseToolIdentifiers(tools)
            let action = CLIParsing.parseAction(isImage: image, tools: identifiers)
            let options = GatewaySendOptions(action: action)
            let shouldStream = stream && !global.json
            let tracker = CLIStreamTracker()
            let streamTask: Task<Void, Never>? = shouldStream
                ? Task {
                    await CLIGenerationStreamer.stream(
                        orchestrator: runtime.orchestrator,
                        output: runtime.output,
                        tracker: tracker
                    )
                }
                : nil

            let result = try await runtime.gateway.send(
                sessionId: sessionId,
                input: input,
                options: options
            )

            if let streamTask {
                await CLIGenerationStreamer.awaitCompletion(
                    streamTask,
                    timeoutNanoseconds: 1_000_000_000
                )
            }

            let didStreamText = await tracker.snapshot()
            let fallback: String
            if let message = result.assistantMessage {
                fallback = message.content
            } else {
                fallback = "Message \(result.messageId.uuidString) sent."
            }

            if shouldStream, didStreamText {
                runtime.output.emit("")
            } else {
                runtime.output.emit(result, fallback: fallback)
            }
        }
    }

    struct History: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            abstract: "Show chat history."
        )

        @OptionGroup
        var global: GlobalOptions

        @Option(name: .long, help: "Session UUID.")
        var session: String

        @Option(name: .long, help: "Maximum number of messages to return.")
        var limit: Int = 50

        func run() async throws {
            let runtime = try await CLIRuntimeProvider.runtime(for: global)
            let sessionId = try CLIParsing.parseUUID(session, field: "session")
            let messages = try await runtime.gateway.history(
                sessionId: sessionId,
                options: GatewayHistoryOptions(limit: limit)
            )
            let fallback = messages.isEmpty
                ? "No messages."
                : messages.map { "\($0.role.rawValue): \($0.content)" }.joined(separator: "\n")
            runtime.output.emit(messages, fallback: fallback)
        }
    }

    struct Rename: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            abstract: "Rename a chat session."
        )

        @OptionGroup
        var global: GlobalOptions

        @Option(name: .long, help: "Session UUID.")
        var session: String

        @Argument(help: "New title.")
        var title: String

        func run() async throws {
            let runtime = try await CLIRuntimeProvider.runtime(for: global)
            let sessionId = try CLIParsing.parseUUID(session, field: "session")
            _ = try await runtime.database.write(
                ChatCommands.Rename(chatId: sessionId, newName: title)
            )
            runtime.output.emit("Renamed session \(sessionId.uuidString)")
        }
    }

    struct Delete: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            abstract: "Delete a chat session."
        )

        @OptionGroup
        var global: GlobalOptions

        @Option(name: .long, help: "Session UUID.")
        var session: String

        func run() async throws {
            let runtime = try await CLIRuntimeProvider.runtime(for: global)
            let sessionId = try CLIParsing.parseUUID(session, field: "session")
            _ = try await runtime.database.write(ChatCommands.Delete(id: sessionId))
            runtime.output.emit("Deleted session \(sessionId.uuidString)")
        }
    }
}
