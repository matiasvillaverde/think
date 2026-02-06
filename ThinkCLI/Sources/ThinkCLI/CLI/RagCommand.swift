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
            let tableName = try resolveTable(table: table, chat: chat, user: user)
            let contentId = try id.map { try CLIParsing.parseUUID($0, field: "id") } ?? UUID()

            let content: String
            if let text, !text.isEmpty {
                content = text
            } else if let file {
                let url = URL(fileURLWithPath: file)
                content = try String(contentsOf: url, encoding: .utf8)
            } else {
                throw ValidationError("Provide --text or --file.")
            }

            try await runtime.database.indexText(content, id: contentId, table: tableName)
            runtime.output.emit("Indexed \(contentId.uuidString) into \(tableName)")
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
            let tableName = try resolveTable(table: table, chat: chat, user: user)
            let results = try await runtime.database.semanticSearch(
                query: query,
                table: tableName,
                numResults: limit,
                threshold: threshold
            )
            let summaries = results.map(RagSearchResultSummary.init(result:))
            let fallback = summaries.isEmpty
                ? "No results."
                : summaries.map { "\($0.score): \($0.text)" }.joined(separator: "\n")
            runtime.output.emit(summaries, fallback: fallback)
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
            let tableName = try resolveTable(table: table, chat: chat, user: user)
            let contentId = try CLIParsing.parseUUID(id, field: "id")
            try await runtime.database.deleteFromIndex(id: contentId, table: tableName)
            runtime.output.emit("Deleted \(contentId.uuidString) from \(tableName)")
        }
    }
}

private func resolveTable(
    table: String?,
    chat: String?,
    user: String?
) throws -> String {
    if let table, !table.isEmpty {
        return table
    }

    if let chat {
        let chatId = try CLIParsing.parseUUID(chat, field: "chat")
        return RagTableName.chatTableName(chatId: chatId)
    }

    if let user {
        let userId = try CLIParsing.parseUUID(user, field: "user")
        return RagTableName.memoryTableName(userId: userId)
    }

    throw ValidationError("Provide --table, --chat, or --user to resolve the RAG table.")
}
