import Abstractions
import Database
import Foundation

enum CLIChatService {
    static func list(runtime: CLIRuntime) async throws {
        let sessions = try await runtime.gateway.listSessions()
        let fallback = sessions.isEmpty
            ? "No sessions."
            : sessions.map { "\($0.id.uuidString)  \($0.title)" }.joined(separator: "\n")
        runtime.output.emit(sessions, fallback: fallback)
    }

    static func create(runtime: CLIRuntime, title: String?) async throws {
        let session = try await runtime.gateway.createSession(title: title)
        let fallback = "Created session \(session.id.uuidString)"
        runtime.output.emit(session, fallback: fallback)
    }

    static func get(runtime: CLIRuntime, sessionId: UUID) async throws {
        let session = try await runtime.gateway.getSession(id: sessionId)
        let fallback = "\(session.id.uuidString)  \(session.title)"
        runtime.output.emit(session, fallback: fallback)
    }

    static func history(
        runtime: CLIRuntime,
        sessionId: UUID,
        limit: Int
    ) async throws {
        let messages = try await runtime.gateway.history(
            sessionId: sessionId,
            options: GatewayHistoryOptions(limit: limit)
        )
        let fallback = messages.isEmpty
            ? "No messages."
            : messages.map { "\($0.role.rawValue): \($0.content)" }.joined(separator: "\n")
        runtime.output.emit(messages, fallback: fallback)
    }

    static func rename(
        runtime: CLIRuntime,
        sessionId: UUID,
        title: String
    ) async throws {
        _ = try await runtime.database.write(
            ChatCommands.Rename(chatId: sessionId, newName: title)
        )
        runtime.output.emit("Renamed session \(sessionId.uuidString)")
    }

    static func delete(runtime: CLIRuntime, sessionId: UUID) async throws {
        _ = try await runtime.database.write(ChatCommands.Delete(id: sessionId))
        runtime.output.emit("Deleted session \(sessionId.uuidString)")
    }

    static func send(
        runtime: CLIRuntime,
        sessionId: UUID,
        input: String,
        tools: [String],
        noTools: Bool,
        image: Bool,
        stream: Bool
    ) async throws {
        let identifiers = try CLIParsing.parseToolIdentifiers(tools)
        let resolvedTools = try await resolveTools(
            runtime: runtime,
            sessionId: sessionId,
            requested: identifiers,
            noTools: noTools
        )
        let action = CLIParsing.parseAction(isImage: image, tools: resolvedTools)
        let options = GatewaySendOptions(action: action)
        let shouldStream = stream && runtime.output.supportsStreaming
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
            if runtime.settings.outputFormat == .text {
                runtime.output.emit("")
            } else {
                runtime.output.emit(result, fallback: fallback)
            }
        } else {
            runtime.output.emit(result, fallback: fallback)
        }
    }

    private static func resolveTools(
        runtime: CLIRuntime,
        sessionId: UUID,
        requested: Set<ToolIdentifier>,
        noTools: Bool
    ) async throws -> Set<ToolIdentifier> {
        if noTools {
            return []
        }

        if runtime.settings.toolAccess == .deny {
            if !requested.isEmpty {
                throw CLIError.toolAccessDenied(action: "chat send")
            }
            return []
        }

        if !requested.isEmpty {
            return requested
        }

        let policy = try await runtime.database.read(
            ToolPolicyCommands.ResolveForChat(chatId: sessionId)
        )
        let allowedTools = policy.allowedTools
        let unsupported: Set<ToolIdentifier> = [.reasoning, .imageGeneration]
        return allowedTools.subtracting(unsupported)
    }
}
