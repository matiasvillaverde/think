import ArgumentParser
import Foundation

struct ChatCommand: AsyncParsableCommand, GlobalOptionsAccessing {
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

    @ParentCommand
    var parent: ThinkCLI

    var parentGlobal: GlobalOptions? { parent.global }
}

extension ChatCommand {
    struct List: AsyncParsableCommand, GlobalOptionsAccessing {
        static let configuration = CommandConfiguration(
            abstract: "List chat sessions."
        )

        @OptionGroup
        var global: GlobalOptions

        @ParentCommand
        var parent: ChatCommand

        var parentGlobal: GlobalOptions? { parent.resolvedGlobal }

        func run() async throws {
            let runtime = try await CLIRuntimeProvider.runtime(for: resolvedGlobal)
            try await CLIChatService.list(runtime: runtime)
        }
    }

    struct Create: AsyncParsableCommand, GlobalOptionsAccessing {
        static let configuration = CommandConfiguration(
            abstract: "Create a new chat session."
        )

        @OptionGroup
        var global: GlobalOptions

        @ParentCommand
        var parent: ChatCommand

        var parentGlobal: GlobalOptions? { parent.resolvedGlobal }

        @Option(name: .long, help: "Optional title for the session.")
        var title: String?

        func run() async throws {
            let runtime = try await CLIRuntimeProvider.runtime(for: resolvedGlobal)
            try await CLIChatService.create(runtime: runtime, title: title)
        }
    }

    struct Get: AsyncParsableCommand, GlobalOptionsAccessing {
        static let configuration = CommandConfiguration(
            abstract: "Fetch a chat session by id."
        )

        @OptionGroup
        var global: GlobalOptions

        @ParentCommand
        var parent: ChatCommand

        var parentGlobal: GlobalOptions? { parent.resolvedGlobal }

        @Argument(help: "Session UUID.")
        var id: String

        func run() async throws {
            let runtime = try await CLIRuntimeProvider.runtime(for: resolvedGlobal)
            let sessionId = try CLIParsing.parseUUID(id, field: "session")
            try await CLIChatService.get(runtime: runtime, sessionId: sessionId)
        }
    }

    struct Send: AsyncParsableCommand, GlobalOptionsAccessing {
        static let configuration = CommandConfiguration(
            abstract: "Send a prompt to a chat session."
        )

        @OptionGroup
        var global: GlobalOptions

        @ParentCommand
        var parent: ChatCommand

        var parentGlobal: GlobalOptions? { parent.resolvedGlobal }

        @Option(name: .long, help: "Session UUID.")
        var session: String

        @Argument(help: "Prompt to send.")
        var input: String?

        @Option(name: .long, help: "Prompt to send (use to avoid conflicts with --tools).")
        var prompt: String?

        @Option(name: .long, parsing: .upToNextOption, help: "Tools to enable.")
        var tools: [String] = []

        @Flag(name: .long, help: "Disable tools for this request.")
        var noTools: Bool = false

        @Flag(name: .long, help: "Use image generation action.")
        var image: Bool = false

        @Flag(
            name: .long,
            help: "Disable output streaming for this request."
        )
        var noStream: Bool = false

        func validate() throws {
            let resolved = (prompt ?? input)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            if resolved.isEmpty {
                throw ValidationError("Provide a prompt via <input> or --prompt.")
            }
        }

        func run() async throws {
            let runtime = try await CLIRuntimeProvider.runtime(for: resolvedGlobal)
            let sessionId = try CLIParsing.parseUUID(session, field: "session")
            let resolvedInput = prompt ?? input ?? ""
            try await CLIChatService.send(
                runtime: runtime,
                sessionId: sessionId,
                input: resolvedInput,
                tools: tools,
                noTools: noTools,
                image: image,
                stream: !noStream
            )
        }
    }

    struct History: AsyncParsableCommand, GlobalOptionsAccessing {
        static let configuration = CommandConfiguration(
            abstract: "Show chat history."
        )

        @OptionGroup
        var global: GlobalOptions

        @ParentCommand
        var parent: ChatCommand

        var parentGlobal: GlobalOptions? { parent.resolvedGlobal }

        @Option(name: .long, help: "Session UUID.")
        var session: String

        @Option(name: .long, help: "Maximum number of messages to return.")
        var limit: Int = 50

        func run() async throws {
            let runtime = try await CLIRuntimeProvider.runtime(for: resolvedGlobal)
            let sessionId = try CLIParsing.parseUUID(session, field: "session")
            try await CLIChatService.history(
                runtime: runtime,
                sessionId: sessionId,
                limit: limit
            )
        }
    }

    struct Rename: AsyncParsableCommand, GlobalOptionsAccessing {
        static let configuration = CommandConfiguration(
            abstract: "Rename a chat session."
        )

        @OptionGroup
        var global: GlobalOptions

        @ParentCommand
        var parent: ChatCommand

        var parentGlobal: GlobalOptions? { parent.resolvedGlobal }

        @Option(name: .long, help: "Session UUID.")
        var session: String

        @Argument(help: "New title.")
        var title: String

        func run() async throws {
            let runtime = try await CLIRuntimeProvider.runtime(for: resolvedGlobal)
            let sessionId = try CLIParsing.parseUUID(session, field: "session")
            try await CLIChatService.rename(
                runtime: runtime,
                sessionId: sessionId,
                title: title
            )
        }
    }

    struct Delete: AsyncParsableCommand, GlobalOptionsAccessing {
        static let configuration = CommandConfiguration(
            abstract: "Delete a chat session."
        )

        @OptionGroup
        var global: GlobalOptions

        @ParentCommand
        var parent: ChatCommand

        var parentGlobal: GlobalOptions? { parent.resolvedGlobal }

        @Option(name: .long, help: "Session UUID.")
        var session: String

        func run() async throws {
            let runtime = try await CLIRuntimeProvider.runtime(for: resolvedGlobal)
            let sessionId = try CLIParsing.parseUUID(session, field: "session")
            try await CLIChatService.delete(runtime: runtime, sessionId: sessionId)
        }
    }
}
