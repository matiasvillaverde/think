import Abstractions
import ArgumentParser
import Foundation

struct RagCommand: AsyncParsableCommand, GlobalOptionsAccessing {
    static let configuration = CommandConfiguration(
        commandName: "rag",
        abstract: "RAG indexing and search operations.",
        subcommands: [Index.self, Search.self, Delete.self]
    )

    @OptionGroup
    var global: GlobalOptions

    @ParentCommand
    var parent: ThinkCLI

    var parentGlobal: GlobalOptions? { parent.global }
}

extension RagCommand {
    struct Index: AsyncParsableCommand, GlobalOptionsAccessing {
        static let configuration = CommandConfiguration(
            abstract: "Index text into RAG."
        )

        @OptionGroup
        var global: GlobalOptions

        @ParentCommand
        var parent: RagCommand

        var parentGlobal: GlobalOptions? { parent.resolvedGlobal }

        @Option(name: .long, help: "RAG table name.")
        var table: String?

        @Option(name: .long, help: "Chat UUID to derive table name.")
        var chat: String?

        @Option(name: .long, help: "User UUID to derive memory table name.")
        var user: String?

        @Option(name: .long, help: "Explicit content id (UUID).")
        var id: String?

        @Option(name: .long, help: "Text to index.")
        var text: String?

        @Option(name: .long, help: "File path to index.")
        var file: String?

        func run() async throws {
            let runtime = try await CLIRuntimeProvider.runtime(for: resolvedGlobal)
            try await CLIRagService.index(
                runtime: runtime,
                table: table,
                chat: chat,
                user: user,
                id: id,
                text: text,
                file: file
            )
        }
    }

    struct Search: AsyncParsableCommand, GlobalOptionsAccessing {
        static let configuration = CommandConfiguration(
            abstract: "Search indexed RAG content."
        )

        @OptionGroup
        var global: GlobalOptions

        @ParentCommand
        var parent: RagCommand

        var parentGlobal: GlobalOptions? { parent.resolvedGlobal }

        @Option(name: .long, help: "RAG table name.")
        var table: String?

        @Option(name: .long, help: "Chat UUID to derive table name.")
        var chat: String?

        @Option(name: .long, help: "User UUID to derive memory table name.")
        var user: String?

        @Option(name: .long, help: "Search query.")
        var query: String

        @Option(name: .long, help: "Number of results.")
        var limit: Int = 10

        @Option(name: .long, help: "Similarity threshold.")
        var threshold: Double = Abstractions.Constants.defaultSearchThreshold

        func run() async throws {
            let runtime = try await CLIRuntimeProvider.runtime(for: resolvedGlobal)
            try await CLIRagService.search(
                runtime: runtime,
                table: table,
                chat: chat,
                user: user,
                query: query,
                limit: limit,
                threshold: threshold
            )
        }
    }

    struct Delete: AsyncParsableCommand, GlobalOptionsAccessing {
        static let configuration = CommandConfiguration(
            abstract: "Delete indexed RAG content."
        )

        @OptionGroup
        var global: GlobalOptions

        @ParentCommand
        var parent: RagCommand

        var parentGlobal: GlobalOptions? { parent.resolvedGlobal }

        @Option(name: .long, help: "RAG table name.")
        var table: String?

        @Option(name: .long, help: "Chat UUID to derive table name.")
        var chat: String?

        @Option(name: .long, help: "User UUID to derive memory table name.")
        var user: String?

        @Argument(help: "Content UUID.")
        var id: String

        func run() async throws {
            let runtime = try await CLIRuntimeProvider.runtime(for: resolvedGlobal)
            try await CLIRagService.delete(
                runtime: runtime,
                table: table,
                chat: chat,
                user: user,
                id: id
            )
        }
    }
}
