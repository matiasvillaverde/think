import Abstractions
import Foundation
import OSLog

/// Strategy for browser search tool
public struct BrowserSearchStrategy: ToolStrategy {
    /// Logger for browser search operations
    private static let logger: Logger = Logger(subsystem: "Tools", category: "BrowserSearchStrategy")
    private let searchEngine: DuckDuckGoSearch = DuckDuckGoSearch()

    public let definition: ToolDefinition = ToolDefinition(
        name: "browser.search",
        description: "Search the web for information",
        schema: """
            {
                "type": "object",
                "properties": {
                    "query": {
                        "type": "string",
                        "description": "The search query"
                    },
                    "site": {
                        "type": "string",
                        "description": "Optional site filter"
                    },
                    "resultCount": {
                        "type": "integer",
                        "description": "Number of results (1-5)",
                        "minimum": 1,
                        "maximum": 5,
                        "default": 3
                    }
                },
                "required": ["query"]
            }
            """
    )

    /// Initialize a new BrowserSearchStrategy
    public init() {
        // No initialization required
    }

    public func execute(request: ToolRequest) -> ToolResponse {
        Self.logger.debug("Processing browser search request for request ID: \(request.id)")

        // Parse arguments
        switch BaseToolStrategy.parseArguments(request) {
        case .failure(let error):
            return BaseToolStrategy.errorResponse(request: request, error: error.message)

        case .success(let json):
            return executeSearch(request: request, json: json)
        }
    }

    private func executeSearch(request: ToolRequest, json: [String: Any]) -> ToolResponse {
        // Validate required query parameter
        guard let query = json["query"] as? String, !query.isEmpty else {
            Self.logger.warning("Browser search request missing query parameter")
            return BaseToolStrategy.errorResponse(
                request: request,
                error: "Missing required parameter: query"
            )
        }

        // Extract optional parameters
        let site: String? = json["site"] as? String
        let resultCount: Int = json["resultCount"] as? Int ?? ToolConstants.defaultSearchResultCount

        Self.logger.info("Performing browser search for query: \(query, privacy: .public)")
        Self.logger.debug("Search parameters - site: \(site ?? "none"), resultCount: \(resultCount)")

        // Use a semaphore to bridge async to sync
        let semaphore: DispatchSemaphore = DispatchSemaphore(value: 0)
        var response: ToolResponse?

        Task {
            do {
                let searchResults: [WebSearchResult] = try await searchEngine.search(
                    query: query,
                    site: site,
                    resultCount: resultCount
                )

                let formattedResult: String = formatSearchResults(
                    query: query,
                    site: site,
                    results: searchResults,
                    count: resultCount
                )

                Self.logger.notice("Browser search completed successfully with \(searchResults.count) results")
                response = BaseToolStrategy.successResponse(
                    request: request,
                    result: formattedResult
                )
            } catch {
                Self.logger.error("Browser search failed: \(error.localizedDescription)")
                response = BaseToolStrategy.errorResponse(
                    request: request,
                    error: "Search failed: \(error.localizedDescription)"
                )
            }
            semaphore.signal()
        }

        let timeoutSeconds: Double = 30.0
        _ = semaphore.wait(timeout: .now() + timeoutSeconds)
        return response
            ?? BaseToolStrategy.errorResponse(
                request: request,
                error: "Search timed out"
            )
    }

    private func formatSearchResults(
        query: String,
        site: String?,
        results: [WebSearchResult],
        count: Int
    ) -> String {
        var result: String = "Web search results for '\(query)'"

        if let site {
            result += " (site: \(site))"
        }

        if results.isEmpty {
            result += "\n\nNo results found."
            return result
        }

        result += "\n\nFound \(results.count) results:"

        for (index, searchResult) in results.prefix(count).enumerated() {
            result += "\n\n\(index + 1). \(searchResult.title)"
            result += "\n   URL: \(searchResult.sourceURL)"
            result += "\n   \(searchResult.snippet)"

            // Include content excerpt from the sophisticated implementation
            if !searchResult.content.isEmpty {
                let contentPreviewLength: Int = 300
                let contentPreview: String = String(
                    searchResult.content.prefix(contentPreviewLength)
                )
                result += "\n   Content: \(contentPreview)..."
            }
        }

        return result
    }
}
