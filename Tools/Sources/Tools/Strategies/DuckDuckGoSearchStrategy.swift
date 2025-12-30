import Abstractions
import Foundation

/// Strategy for DuckDuckGo search engine
public struct DuckDuckGoSearchStrategy: ToolStrategy {
    private let searchEngine: DuckDuckGoSearch

    /// The tool definition
    public let definition: ToolDefinition = ToolDefinition(
        name: "duckduckgo_search",
        description: "Search using DuckDuckGo with privacy protection",
        schema: """
        {
            "type": "object",
            "properties": {
                "query": {
                    "type": "string",
                    "description": "The search query"
                },
                "region": {
                    "type": "string",
                    "description": "Region for results (e.g., us-en, uk-en)",
                    "default": "wt-wt"
                },
                "instant_answers": {
                    "type": "boolean",
                    "description": "Include instant answers",
                    "default": false
                },
                "no_redirect": {
                    "type": "boolean",
                    "description": "Disable redirect following",
                    "default": false
                },
                "count": {
                    "type": "integer",
                    "description": "Number of results (1-10)",
                    "minimum": 1,
                    "maximum": 10,
                    "default": 5
                }
            },
            "required": ["query"]
        }
        """
    )

    /// Initialize a new DuckDuckGoSearchStrategy
    public init() {
        self.searchEngine = DuckDuckGoSearch()
    }

    /// Internal initializer for injecting a custom search engine (testing)
    internal init(searchEngine: DuckDuckGoSearch) {
        self.searchEngine = searchEngine
    }

    /// Execute the search request
    /// - Parameter request: The tool request
    /// - Returns: The tool response with search results
    public func execute(request: ToolRequest) async -> ToolResponse {
        // Parse arguments
        switch BaseToolStrategy.parseArguments(request) {
        case .failure(let error):
            return BaseToolStrategy.errorResponse(request: request, error: error.message)

        case .success(let json):
            return await executeSearch(request: request, parameters: json)
        }
    }

    private func executeSearch(request: ToolRequest, parameters: [String: Any]) async -> ToolResponse {
        // Validate required query parameter
        guard let query = parameters["query"] as? String, !query.isEmpty else {
            return BaseToolStrategy.errorResponse(
                request: request,
                error: "Missing required parameter: query"
            )
        }

        // Extract optional parameters
        let searchParams: SearchParameters = extractParameters(from: parameters)

        do {
            let searchResults: [WebSearchResult] = try await searchEngine.search(
                query: query,
                resultCount: searchParams.count
            )

            let formattedResult: String = formatSearchResults(
                query: query,
                results: searchResults,
                params: searchParams
            )

            return BaseToolStrategy.successResponse(
                request: request,
                result: formattedResult
            )
        } catch {
            return BaseToolStrategy.errorResponse(
                request: request,
                error: "Search failed: \(error.localizedDescription)"
            )
        }
    }

    private struct SearchParameters {
        let region: String
        let instantAnswers: Bool
        let noRedirect: Bool
        let count: Int
    }

    private func extractParameters(from json: [String: Any]) -> SearchParameters {
        let resultCountDefault: Int = 5
        return SearchParameters(
            region: json["region"] as? String ?? "wt-wt",
            instantAnswers: json["instant_answers"] as? Bool ?? false,
            noRedirect: json["no_redirect"] as? Bool ?? false,
            count: json["count"] as? Int ?? resultCountDefault
        )
    }

    private func formatSearchResults(
        query: String,
        results: [WebSearchResult],
        params: SearchParameters
    ) -> String {
        var result: String = "DuckDuckGo search results for '\(query)'"

        if params.region != "wt-wt" {
            result += " (region: \(params.region))"
        }

        if params.instantAnswers {
            result += " (instant answers: enabled)"
        }

        if params.noRedirect {
            result += " (no redirect)"
        }

        result += "\n\nFound \(results.count) results:"

        for (index, searchResult) in results.prefix(params.count).enumerated() {
            result += "\n\n\(index + 1). \(searchResult.title)"
            result += "\n   URL: \(searchResult.sourceURL)"
            result += "\n   \(searchResult.snippet)"

            // Include content excerpt from the sophisticated implementation
            if !searchResult.content.isEmpty {
                let contentPreviewLength: Int = 200
                let contentPreview: String = String(searchResult.content.prefix(contentPreviewLength))
                result += "\n   Content: \(contentPreview)..."
            }
        }

        if params.instantAnswers, query.lowercased().contains("weather") {
            result += "\n\nInstant Answer: Weather information not yet implemented"
        }

        return result
    }
}
