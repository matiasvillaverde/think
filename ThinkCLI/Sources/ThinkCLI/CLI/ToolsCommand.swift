import ArgumentParser
import Foundation

struct ToolsCommand: AsyncParsableCommand, GlobalOptionsAccessing {
    static let configuration = CommandConfiguration(
        commandName: "tools",
        abstract: "List and run tools.",
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
            abstract: "List tools."
        )

        @OptionGroup
        var global: GlobalOptions

        @ParentCommand
        var parent: ToolsCommand

        var parentGlobal: GlobalOptions? { parent.resolvedGlobal }

        func run() async throws {
            let runtime = try await CLIRuntimeProvider.runtime(for: resolvedGlobal)
            try await CLIToolsService.list(runtime: runtime)
        }
    }

    struct Run: AsyncParsableCommand, GlobalOptionsAccessing {
        static let configuration = CommandConfiguration(
            abstract: "Run a tool."
        )

        @OptionGroup
        var global: GlobalOptions

        @ParentCommand
        var parent: ToolsCommand

        var parentGlobal: GlobalOptions? { parent.resolvedGlobal }

        @Argument(help: "Tool name.")
        var name: String

        @Option(name: .long, help: "JSON arguments payload.")
        var args: String

        func run() async throws {
            let runtime = try await CLIRuntimeProvider.runtime(for: resolvedGlobal)
            try await CLIToolsService.run(runtime: runtime, name: name, arguments: args)
        }
    }
}
