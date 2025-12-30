import Foundation
import OSLog
import SwiftSoup

/// Service for searching web content through DuckDuckGo and extracting clean, readable content
internal final actor DuckDuckGoSearch {
    deinit {
        // No cleanup required
    }
    // MARK: - Properties

    /// A dedicated logger for the search service
    private let logger: Logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "com.search.DuckDuckGo",
        category: "DuckDuckGoSearch"
    )

    /// URLSession for handling network requests
    private let session: URLSession

    /// Configuration for search behavior
    private let config: Configuration

    // MARK: - Types

    /// Configuration options for the search service
    internal struct Configuration {
        /// Maximum number of results to return
        let maxResultCount: Int

        /// Network request timeout in seconds
        let requestTimeout: TimeInterval

        /// Maximum number of concurrent network requests
        let concurrentFetches: Int

        /// CSS selectors to identify main content (in priority order)
        let contentSelectors: [String]

        /// User agent string for requests
        let userAgent: String

        /// Create a configuration with custom settings
        /// - Parameters:
        ///   - maxResultCount: Maximum number of search results to return (1-10)
        ///   - requestTimeout: Timeout for network requests in seconds
        ///   - concurrentFetches: Maximum number of concurrent fetches
        ///   - contentSelectors: CSS selectors to identify main content areas
        ///   - userAgent: Browser user agent string for requests
        init(
            maxResultCount: Int = 5,
            requestTimeout: TimeInterval = 30.0,
            concurrentFetches: Int = 3,
            contentSelectors: [String] = [],
            userAgent: String = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) " +
                "AppleWebKit/605.1.15"
        ) {
            let minCount: Int = 1
            let maxCount: Int = 10
            self.maxResultCount = min(max(maxResultCount, minCount), maxCount)
            self.requestTimeout = requestTimeout
            self.concurrentFetches = concurrentFetches
            self.userAgent = userAgent

            // Default content selectors if none provided
            self.contentSelectors = contentSelectors.isEmpty ? [
                "main", "article", "#content", "#main", "#main-content",
                ".content", ".main", ".main-content", ".post", ".article",
                "div[role=main]", "[itemprop=articleBody]", "[itemprop=mainContentOfPage]"
            ] : contentSelectors
        }
    }

    /// Error types specific to the search process
    internal enum SearchError: Error, LocalizedError {
        /// Invalid date range (start date after end date)
        case invalidDateRange

        /// URL could not be constructed or is malformed
        case invalidURL(String)

        /// Network request failed
        case networkError(Error)

        /// Failed to parse HTML content
        case parsingError(Error)

        /// Failed to decode response data to string
        case decodingError

        /// No results found for query
        case noResults

        var errorDescription: String? {
            switch self {
            case .invalidDateRange:
                return "Invalid date range: start date must be before end date"

            case .invalidURL(let url):
                return "Invalid URL: \(url)"

            case .networkError(let error):
                return "Network error: \(error.localizedDescription)"

            case .parsingError(let error):
                return "HTML parsing error: \(error.localizedDescription)"

            case .decodingError:
                return "Failed to decode HTML content"

            case .noResults:
                return "No results found for the search query"
            }
        }
    }

    // MARK: - Initialization

    /// Initialize the search service with custom configuration
    /// - Parameter configuration: Service configuration options
    init(configuration: Configuration = Configuration(), session: URLSession? = nil) {
        if let session {
            self.session = session
        } else {
            let sessionConfig: URLSessionConfiguration = URLSessionConfiguration.default
            sessionConfig.timeoutIntervalForRequest = configuration.requestTimeout
            let resourceTimeoutMultiplier: Double = 2.0
            sessionConfig.timeoutIntervalForResource =
                configuration.requestTimeout * resourceTimeoutMultiplier

            self.session = URLSession(configuration: sessionConfig)
        }
        self.config = configuration
    }

    // MARK: - Methods

    /// Search for web content matching the query and extract clean, readable content
    /// - Parameters:
    ///   - query: Search query text
    ///   - site: Optional domain to restrict search results to
    ///   - resultCount: Number of results to return (overrides configuration if provided)
    ///   - dateRange: Optional date range for search results
    /// - Returns: Array of SearchResult objects containing cleaned content
    internal func search(
        query: String,
        site: String? = nil,
        resultCount: Int? = nil,
        dateRange: ClosedRange<Date>? = nil
    ) async throws -> [WebSearchResult] {
        // Validate parameters
        if let dateRange, dateRange.lowerBound > dateRange.upperBound {
            throw SearchError.invalidDateRange
        }

        let maxCount: Int = resultCount ?? config.maxResultCount

        // Build search query and URL
        let searchData: (request: URLRequest, referer: URL) = try buildSearchRequest(
            query: query,
            site: site,
            dateRange: dateRange
        )

        // Perform the search to get result links
        let startTime: Date = Date()
        logger.info("Starting search for query: \"\(query)\"")

        let searchResults: [(url: URL, snippet: String)] = try await performSearch(
            using: searchData.request
        )

        if searchResults.isEmpty {
            logger.warning("No results found for query: \"\(query)\"")
            throw SearchError.noResults
        }

        logger.info("Found \(searchResults.count) results for query \"\(query)\"")

        // Fetch and process content for each result
        let results: [WebSearchResult] = try await fetchContentForResults(
            searchResults: searchResults,
            maxCount: min(maxCount, config.maxResultCount)
        )

        let duration: TimeInterval = Date().timeIntervalSince(startTime)
        let durationString: String = String(format: "%.2f", duration)
        logger.info(
            "Search completed in \(durationString)s with \(results.count) processed results"
        )

        return results
    }

    // MARK: - Private Methods - Search Request Handling

    /// Build the search request for DuckDuckGo
    private func buildSearchRequest(
        query: String,
        site: String?,
        dateRange: ClosedRange<Date>?
    ) throws -> (request: URLRequest, referer: URL) {
        // Build complete query string
        var searchTerms: String = query.trimmingCharacters(in: .whitespacesAndNewlines)

        if let site = site?.trimmingCharacters(in: .whitespacesAndNewlines), !site.isEmpty {
            searchTerms += " site:\(site)"
        }

        // Create the URL components
        guard var components = URLComponents(string: "https://html.duckduckgo.com/html/") else {
            throw SearchError.invalidURL("Could not create search URL")
        }

        // Add query parameters
        var queryItems: [URLQueryItem] = [URLQueryItem(name: "q", value: searchTerms)]

        // Add date filter if needed
        if let dateRange {
            let formatter: DateFormatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"

            let startDate: String = formatter.string(from: dateRange.lowerBound)
            let endDate: String = formatter.string(from: dateRange.upperBound)

            queryItems.append(
                URLQueryItem(name: "df", value: "\(startDate)..\(endDate)")
            )
        }

        components.queryItems = queryItems

        // Generate final URL
        guard let url = components.url else {
            throw SearchError.invalidURL("Failed to construct search URL")
        }

        // Create referer URL for request headers
        guard let refererURL = URL(string: "https://duckduckgo.com/") else {
            throw SearchError.invalidURL("Could not create referer URL")
        }

        // Configure request
        var request: URLRequest = URLRequest(url: url)
        request.setValue(config.userAgent, forHTTPHeaderField: "User-Agent")
        request.setValue(refererURL.absoluteString, forHTTPHeaderField: "Referer")
        request.timeoutInterval = config.requestTimeout

        return (request, refererURL)
    }

    /// Execute search and extract result URLs and snippets
    private func performSearch(using request: URLRequest) async throws -> [(url: URL, snippet: String)] {
        do {
            // Fetch search results page
            let (data, response): (Data, URLResponse) = try await session.data(for: request)

            let minSuccessCode: Int = 200
            let maxSuccessCode: Int = 299
            guard let httpResponse = response as? HTTPURLResponse,
                (minSuccessCode...maxSuccessCode).contains(httpResponse.statusCode) else {
                throw SearchError.networkError(NSError(
                    domain: String(describing: Self.self),
                    code: (response as? HTTPURLResponse)?.statusCode ?? -1,
                    userInfo: [NSLocalizedDescriptionKey: "HTTP error"]
                ))
            }

            // Convert data to string
            guard let html = String(data: data, encoding: .utf8) else {
                throw SearchError.decodingError
            }

            // Parse results using SwiftSoup
            return try parseSearchResults(from: html)
        } catch let error as SearchError {
            throw error
        } catch {
            logger.error("Search network error: \(error.localizedDescription)")
            throw SearchError.networkError(error)
        }
    }

    /// Parse search results HTML to extract URLs and snippets
    private func parseSearchResults(from html: String) throws -> [(url: URL, snippet: String)] {
        do {
            // Parse the HTML document
            let document: Document = try SwiftSoup.parse(html)

            // Select result containers
            let results: Elements = try document.select(".result")
            var searchResults: [(url: URL, snippet: String)] = []

            for result in results {
                // Extract URL
                if let link = try result.select("a.result__a").first(),
                    let href = try? link.attr("href") {
                    // Parse the URL from DuckDuckGo's redirect format
                    if let components = URLComponents(string: href),
                        let redirectParam = components.queryItems?
                            .first(where: { $0.name == "uddg" })?.value,
                        let decodedURL = redirectParam.removingPercentEncoding,
                        let url = URL(string: decodedURL) {
                        // Extract snippet text
                        let snippetElement: Element? = try result.select(".result__snippet").first()
                        let snippet: String = try snippetElement?.text() ?? ""

                        if !snippet.isEmpty {
                            searchResults.append((url: url, snippet: snippet))
                        }
                    }
                }
            }

            return searchResults
        } catch {
            logger.error("Failed to parse search results: \(error.localizedDescription)")
            throw SearchError.parsingError(error)
        }
    }

    // MARK: - Private Methods - Content Extraction

    /// Fetch and process content for search results
    private func fetchContentForResults(
        searchResults: [(url: URL, snippet: String)],
        maxCount: Int
    ) async throws -> [WebSearchResult] {
        if searchResults.isEmpty {
            return []
        }

        // Create a task group to process URLs concurrently
        return try await withThrowingTaskGroup(of: WebSearchResult?.self) { group in
            try await processConcurrentSearchResults(
                group: &group,
                searchResults: searchResults,
                maxCount: maxCount
            )
        }
    }

    /// Process search results concurrently using a task group
    private func processConcurrentSearchResults(
        group: inout ThrowingTaskGroup<WebSearchResult?, Error>,
        searchResults: [(url: URL, snippet: String)],
        maxCount: Int
    ) async throws -> [WebSearchResult] {
        var results: [WebSearchResult] = []
        let limitedResults: ArraySlice<(url: URL, snippet: String)> =
            searchResults.prefix(maxCount)

        // Add initial batch of tasks (limited by concurrentFetches)
        for (index, result) in limitedResults.enumerated()
            where index < config.concurrentFetches {
            group.addTask {
                await self.extractContent(from: result.url, snippet: result.snippet)
            }
        }

        // Track which URLs have been processed
        var processedCount: Int = min(config.concurrentFetches, limitedResults.count)

        // Process results as they complete
        while let result = try await group.next() {
            // Add next task if there are more URLs to process
            if processedCount < limitedResults.count {
                let nextResult: (url: URL, snippet: String) = limitedResults[
                    limitedResults.startIndex + processedCount
                ]
                group.addTask {
                    await self.extractContent(
                        from: nextResult.url,
                        snippet: nextResult.snippet
                    )
                }
                processedCount += 1
            }

            // Add valid result to collection
            if let result {
                results.append(result)
            }

            // Check if we have enough results
            if results.count >= maxCount {
                group.cancelAll()
                break
            }
        }

        return results
    }

    /// Extract content from a single URL
    private func extractContent(from url: URL, snippet: String) async -> WebSearchResult? {
        do {
            // Fetch the webpage
            let html: String = try await fetchHTML(from: url)

            // Parse with SwiftSoup
            let document: Document = try SwiftSoup.parse(html)

            // Extract title
            let title: String = try document.title()

            // Extract main content
            let content: String = try extractMainContent(from: document)

            return WebSearchResult(
                title: title,
                snippet: snippet,
                sourceURL: url.absoluteString,
                content: content,
                fetchDate: Date()
            )
        } catch {
            logger.error(
                "Failed to process URL \(url.absoluteString): \(error.localizedDescription)"
            )
            return nil
        }
    }

    /// Fetch HTML content from a URL with proper encoding handling
    private func fetchHTML(from url: URL) async throws -> String {
        do {
            var request: URLRequest = URLRequest(url: url)
            request.setValue(config.userAgent, forHTTPHeaderField: "User-Agent")
            request.timeoutInterval = config.requestTimeout

            let (data, response): (Data, URLResponse) = try await session.data(for: request)

            let minSuccessCode: Int = 200
            let maxSuccessCode: Int = 299
            guard let httpResponse = response as? HTTPURLResponse,
                (minSuccessCode...maxSuccessCode).contains(httpResponse.statusCode) else {
                throw SearchError.networkError(NSError(
                    domain: String(describing: Self.self),
                    code: (response as? HTTPURLResponse)?.statusCode ?? -1,
                    userInfo: [
                        NSLocalizedDescriptionKey: "Failed to load URL: \(url.absoluteString)"
                    ]
                ))
            }

            // Determine text encoding from HTTP headers if available
            let encoding: String.Encoding = determineEncoding(from: httpResponse, data: data)

            guard let html = String(data: data, encoding: encoding) else {
                // Try alternative encodings if the first one fails
                for fallbackEncoding in [
                    String.Encoding.utf8, .isoLatin1, .windowsCP1252, .ascii
                ] {
                    if fallbackEncoding != encoding,
                        let html = String(data: data, encoding: fallbackEncoding) {
                        return html
                    }
                }
                throw SearchError.decodingError
            }

            return html
        } catch let error as SearchError {
            throw error
        } catch {
            logger.error("Failed to fetch \(url.absoluteString): \(error.localizedDescription)")
            throw SearchError.networkError(error)
        }
    }

    /// Determine the text encoding from HTTP response headers or data patterns
    private func determineEncoding(
        from response: HTTPURLResponse,
        data: Data
    ) -> String.Encoding {
        // Try to get encoding from Content-Type header
        if let encoding = extractEncodingFromContentType(response: response) {
            return encoding
        }

        // Try to detect encoding from data patterns if no header available
        if let encoding = detectEncodingFromBOM(data: data) {
            return encoding
        }

        // Default encoding
        return .utf8
    }

    /// Extract encoding from Content-Type header
    private func extractEncodingFromContentType(response: HTTPURLResponse) -> String.Encoding? {
        guard let contentType = response.value(forHTTPHeaderField: "Content-Type"),
            let charsetRange = contentType.range(of: "charset=", options: .caseInsensitive) else {
            return nil
        }

        let charsetStartIndex: String.Index = charsetRange.upperBound
        let charset: String

        if let semicolonRange = contentType[charsetStartIndex...].firstIndex(of: ";") {
            charset = String(contentType[charsetStartIndex..<semicolonRange])
                .trimmingCharacters(in: .whitespacesAndNewlines)
        } else {
            charset = String(contentType[charsetStartIndex...])
                .trimmingCharacters(in: .whitespacesAndNewlines)
        }

        return encodingFromCharset(charset)
    }

    /// Map charset string to encoding
    private func encodingFromCharset(_ charset: String) -> String.Encoding? {
        switch charset.lowercased() {
        case "iso-8859-1", "latin1":
            return .isoLatin1

        case "windows-1252":
            return .windowsCP1252

        case "ascii":
            return .ascii

        case "utf-16":
            return .utf16

        case "utf-16le":
            return .utf16LittleEndian

        case "utf-16be":
            return .utf16BigEndian

        case "utf-8":
            return .utf8

        default:
            return nil
        }
    }

    /// Detect encoding from BOM (Byte Order Mark)
    private func detectEncodingFromBOM(data: Data) -> String.Encoding? {
        // Check for UTF-8 BOM
        if dataStartsWith(data, bom: ToolConstants.BOM.utf8) {
            return .utf8
        }

        // Check for UTF-16 BOMs
        if dataStartsWith(data, bom: ToolConstants.BOM.utf16BE) {
            return .utf16BigEndian
        }

        if dataStartsWith(data, bom: ToolConstants.BOM.utf16LE) {
            return .utf16LittleEndian
        }

        return nil
    }

    /// Check if data starts with given BOM
    private func dataStartsWith(_ data: Data, bom: [UInt8]) -> Bool {
        guard data.count >= bom.count else {
            return false
        }

        for (index, byte) in bom.enumerated() where data[index] != byte {
            return false
        }
        return true
    }

    /// Extract the main content from an HTML document
    private func extractMainContent(from document: Document) throws -> String {
        // Make a copy of the document to avoid modifying the original
        let contentDocument: Document = try SwiftSoup.parse(document.html())

        // Remove elements that typically contain non-content
        let selectorsToRemove: [String] = [
            "script", "style", "noscript", "iframe", "form", "nav",
            "header:not(article header)", "footer:not(article footer)",
            ".sidebar", ".comments", ".advertisement", ".ad",
            "[class*=share]", "[class*=social]", ".related", ".recommended"
        ]
        try contentDocument.select(selectorsToRemove.joined(separator: ", ")).remove()

        // Try to find main content container using selectors
        for selector in config.contentSelectors {
            let elements: Elements = try contentDocument.select(selector)
            if !elements.isEmpty() {
                if let element: Element = elements.first() {
                    let content: String = try element.text()
                    // Basic heuristic to ensure we have substantial content
                    let minContentLength: Int = 200
                    if content.count > minContentLength {
                        return cleanText(content)
                    }
                }
            }
        }

        // If no content found with selectors, try using paragraphs
        let paragraphs: Elements = try contentDocument.select("p")
        if !paragraphs.isEmpty() {
            var combinedText: String = ""
            let minParagraphLength: Int = 20
            for paragraph: Element in paragraphs {
                let paragraphText: String = try paragraph.text()
                // Skip very short paragraphs that are likely not main content
                if paragraphText.count > minParagraphLength {
                    combinedText += paragraphText + "\n\n"
                }
            }

            let minCombinedLength: Int = 200
            if combinedText.count > minCombinedLength {
                return cleanText(combinedText)
            }
        }

        // Fallback to body text if no specific content container found
        if let bodyText = try contentDocument.body()?.text(), !bodyText.isEmpty {
            return cleanText(bodyText)
        }

        // Final fallback to entire document text
        return cleanText(try contentDocument.text())
    }

    /// Clean and normalize text for better readability
    private func cleanText(_ text: String) -> String {
        text
            // Normalize whitespace
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            // Split into sentences for better LLM processing
            .replacingOccurrences(of: "\\. ", with: ".\n", options: .regularExpression)
            // Remove redundant newlines
            .replacingOccurrences(of: "\n+", with: "\n", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
