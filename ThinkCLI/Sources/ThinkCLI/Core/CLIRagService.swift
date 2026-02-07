import Abstractions
import ArgumentParser
import Foundation

enum CLIRagService {
    static func index(
        runtime: CLIRuntime,
        table: String?,
        chat: String?,
        user: String?,
        id: String?,
        text: String?,
        file: String?
    ) async throws {
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

    static func search(
        runtime: CLIRuntime,
        table: String?,
        chat: String?,
        user: String?,
        query: String,
        limit: Int,
        threshold: Double
    ) async throws {
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

    static func delete(
        runtime: CLIRuntime,
        table: String?,
        chat: String?,
        user: String?,
        id: String
    ) async throws {
        let tableName = try resolveTable(table: table, chat: chat, user: user)
        let contentId = try CLIParsing.parseUUID(id, field: "id")
        try await runtime.database.deleteFromIndex(id: contentId, table: tableName)
        runtime.output.emit("Deleted \(contentId.uuidString) from \(tableName)")
    }

    private static func resolveTable(
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
}
