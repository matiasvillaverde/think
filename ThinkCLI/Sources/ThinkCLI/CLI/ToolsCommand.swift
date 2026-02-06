import Abstractions
import ArgumentParser
import Foundation

struct ToolsCommand: AsyncParsableCommand, GlobalOptionsAccessing {
    static let configuration = CommandConfiguration(
        commandName: "tools",
        abstract: "List or run tools.",
        subcommands: [List.self, Run.self]
    )

    @OptionGroup
    var global: GlobalOptions

    @ParentCommand
    var parent: ThinkCLI

    var parentGlobal: GlobalOptions? { parent.global }
}

extension ToolsCommand {
    struct List: AsyncParsableCommand, GlobalOptionsAccessing {
        static let configuration = CommandConfiguration(
            abstract: "List available tools."
        )

        @OptionGroup
        var global: GlobalOptions

        @ParentCommand
        var parent: ToolsCommand

        var parentGlobal: GlobalOptions? { parent.resolvedGlobal }

        func run() async throws {
            let runtime = try await CLIRuntimeProvider.runtime(for: resolvedGlobal)
            await runtime.tooling.configureTool(identifiers: Set(ToolIdentifier.allCases))
            let definitions = await runtime.tooling.getAllToolDefinitions()
            let summaries = definitions.map(ToolDefinitionSummary.init(definition:))
            let fallback = summaries.isEmpty
                ? "No tools available."
                : summaries.map { "\($0.name) - \($0.description)" }.joined(separator: "\n")
            runtime.output.emit(summaries, fallback: fallback)
        }
    }

    struct Run: AsyncParsableCommand, GlobalOptionsAccessing {
        static let configuration = CommandConfiguration(
            abstract: "Run a tool with JSON arguments."
        )

        @OptionGroup
        var global: GlobalOptions

        @ParentCommand
        var parent: ToolsCommand

        var parentGlobal: GlobalOptions? { parent.resolvedGlobal }

        @Argument(help: "Tool name (e.g., browser.search).")
        var name: String

        @Option(name: .long, help: "JSON arguments for the tool.")
        var args: String = "{}"

        @Option(name: .long, help: "Optional chat UUID for tool context.")
        var chat: String?

        @Option(name: .long, help: "Optional message UUID for tool context.")
        var message: String?

        func run() async throws {
            let runtime = try await CLIRuntimeProvider.runtime(for: resolvedGlobal)
            let identifiers = try CLIParsing.parseToolIdentifiers([name])
            guard let identifier = identifiers.first else {
                throw ValidationError("Unknown tool: \(name)")
            }
            await runtime.tooling.configureTool(identifiers: [identifier])

            var request = ToolRequest(name: identifier.toolName, arguments: args)
            if let chat, let message {
                request = request.withContext(
                    chatId: try CLIParsing.parseUUID(chat, field: "chat"),
                    messageId: try CLIParsing.parseUUID(message, field: "message")
                )
            } else if let chat {
                request = request.withContext(
                    chatId: try CLIParsing.parseUUID(chat, field: "chat"),
                    messageId: nil
                )
            }

            let responses = await runtime.tooling.executeTools(toolRequests: [request])
            let fallback = responses.map { response in
                response.error ?? response.result
            }.joined(separator: "\n")
            runtime.output.emit(responses, fallback: fallback)
        }
    }
}
