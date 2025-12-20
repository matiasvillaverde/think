import Abstractions
import Foundation
import os

/// Strategy for semantic search tool
public struct SemanticSearchStrategy: ToolStrategy {
    private static let logger: Logger = Logger(subsystem: "Tools", category: "SemanticSearchStrategy")
    private let database: any DatabaseProtocol
    private let chatId: UUID
    private let fileTitles: [String]

    public var definition: ToolDefinition {
        let baseDescription: String = "Perform semantic search over attached documents"
        let fileContext: String = buildFileContext()
        let fullDescription: String = "\(baseDescription). \(fileContext)"

        return ToolDefinition(
            name: "semantic_search",
            description: fullDescription,
            schema: """
            {
                "type": "object",
                "properties": {
                    "query": {
                        "type": "string",
                        "description": "The search query"
                    },
                    "resultCount": {
                        "type": "integer",
                        "description": "Number of results to return",
                        "minimum": 1,
                        "maximum": 20,
                        "default": 5
                    },
                    "threshold": {
                        "type": "number",
                        "description": "Maximum distance threshold (lower = more similar)",
                        "minimum": 0,
                        "default": \(ToolConstants.defaultSemanticSearchThreshold)
                    }
                },
                "required": ["query"]
            }
            """
        )
    }

    public init(database: any DatabaseProtocol, chatId: UUID, fileTitles: [String]) {
        self.database = database
        self.chatId = chatId
        self.fileTitles = fileTitles
        Self.logger.debug("Initializing SemanticSearchStrategy with \(fileTitles.count) files")
    }

    private func buildFileContext() -> String {
        guard !fileTitles.isEmpty else {
            return "No files currently attached"
        }

        let fileList: String = fileTitles.joined(separator: ", ")
        return "Available files: \(fileList). Use this tool to search for specific information within these files"
    }

    public func execute(request: ToolRequest) async -> ToolResponse {
        // Parse arguments
        switch BaseToolStrategy.parseArguments(request) {
        case .failure(let error):
            return BaseToolStrategy.errorResponse(request: request, error: error.message)

        case .success(let json):
            // Validate required query parameter
            guard let query = json["query"] as? String, !query.isEmpty else {
                return BaseToolStrategy.errorResponse(
                    request: request,
                    error: "Missing required parameter: query"
                )
            }

            // Extract optional parameters with defaults
            let resultCount: Int = json["resultCount"] as? Int ?? ToolConstants.defaultSemanticSearchResults
            let threshold: Double = json["threshold"] as? Double ?? ToolConstants.defaultSemanticSearchThreshold

            // Perform semantic search
            do {
                Self.logger.info("Performing semantic search with query length: \(query.count)")
                let tableName: String = RagTableName.chatTableName(chatId: chatId)
                Self.logger.debug("Search parameters - count: \(resultCount), threshold: \(threshold)")
                let results: [SearchResult] = try await database.semanticSearch(
                    query: query,
                    table: tableName,
                    numResults: resultCount,
                    threshold: threshold
                )

                Self.logger.notice("Semantic search completed with \(results.count) results")
                // Format results
                let resultsText: String = formatResults(results, count: resultCount)
                return BaseToolStrategy.successResponse(
                    request: request,
                    result: resultsText
                )
            } catch {
                Self.logger.error("Semantic search failed: \(error.localizedDescription)")
                return BaseToolStrategy.errorResponse(
                    request: request,
                    error: "Search failed: \(error.localizedDescription)"
                )
            }
        }
    }

    private func formatResults(_ results: [SearchResult], count: Int) -> String {
        if results.isEmpty {
            return "No results found"
        }

        let resultsText: String = results
            .prefix(count)
            .enumerated()
            .map { index, result in
                "Result \(index + 1): \(result.text)"
            }
            .joined(separator: "\n")

        return "Found \(count) results:\n\(resultsText)"
    }
}
