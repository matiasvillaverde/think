import Foundation
@testable import Tools

private enum DuckDuckGoStubConstants {
    static let statusOK: Int = 200
    static let statusError: Int = 500
    static let contentRepeatCount: Int = 10
}

private func makeURL(_ string: String) -> URL {
    guard let url: URL = URL(string: string) else {
        preconditionFailure("Invalid URL string: \(string)")
    }
    return url
}

private func makeResponse(
    url: URL,
    statusCode: Int,
    headerFields: [String: String]
) -> HTTPURLResponse {
    guard let response: HTTPURLResponse = HTTPURLResponse(
        url: url,
        statusCode: statusCode,
        httpVersion: nil,
        headerFields: headerFields
    ) else {
        preconditionFailure("Failed to create HTTPURLResponse for \(url)")
    }
    return response
}

internal class StubURLProtocol: URLProtocol {
    private static let handlerStore: RequestHandlerStore = RequestHandlerStore()

    deinit {
        // No-op
    }

    override class func canInit(with _: URLRequest) -> Bool {
        true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        guard let handler = Self.handlerStore.get() else {
            let fallbackURL: URL = request.url ?? makeURL("https://example.com")
            let response: HTTPURLResponse = makeResponse(
                url: fallbackURL,
                statusCode: DuckDuckGoStubConstants.statusError,
                headerFields: [:]
            )
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocolDidFinishLoading(self)
            return
        }

        do {
            let result: (HTTPURLResponse, Data) = try handler(request)
            let response: HTTPURLResponse = result.0
            let data: Data = result.1
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    static func setHandler(
        _ handler: (@Sendable (URLRequest) throws -> (HTTPURLResponse, Data))?
    ) {
        handlerStore.set(handler)
    }

    static func registerHandler(
        _ handler: @escaping @Sendable (URLRequest) throws -> (HTTPURLResponse, Data)
    ) {
        handlerStore.register(handler)
    }

    static func unregisterHandler() {
        handlerStore.unregister()
    }

    override func stopLoading() {
        // No-op
    }
}

internal enum DuckDuckGoStub {
    struct SearchResult {
        let title: String
        let url: URL
        let snippet: String
    }

    static func makeSession(
        handler: @escaping @Sendable (URLRequest) throws -> (HTTPURLResponse, Data)
    ) -> URLSession {
        StubURLProtocol.registerHandler(handler)
        let config: URLSessionConfiguration = URLSessionConfiguration.ephemeral
        config.protocolClasses = [StubURLProtocol.self]
        return URLSession(configuration: config)
    }

    static func reset() {
        StubURLProtocol.unregisterHandler()
    }

    static func defaultHandler(for request: URLRequest) throws -> (HTTPURLResponse, Data) {
        guard let url: URL = request.url else {
            throw URLError(.badURL)
        }

        if url.host == "html.duckduckgo.com" {
            let query: String = URLComponents(url: url, resolvingAgainstBaseURL: false)?
                .queryItems?
                .first { $0.name == "q" }?
                .value ?? ""

            let results: [SearchResult] = Self.resultsForQuery(query)
            let html: String = Self.makeSearchHTML(results: results)
            let response: HTTPURLResponse = makeResponse(
                url: url,
                statusCode: DuckDuckGoStubConstants.statusOK,
                headerFields: ["Content-Type": "text/html; charset=utf-8"]
            )
            return (response, Data(html.utf8))
        }

        let html: String = Self.makeContentHTML(
            title: "Example Page",
            body: Self.longContent(forHost: url.host ?? "example.com")
        )
        let response: HTTPURLResponse = makeResponse(
            url: url,
            statusCode: DuckDuckGoStubConstants.statusOK,
            headerFields: ["Content-Type": "text/html; charset=utf-8"]
        )
        return (response, Data(html.utf8))
    }

    private static func resultsForQuery(_ query: String) -> [SearchResult] {
        if query.contains("site:apple.com") {
            return [
                SearchResult(
                    title: "Apple Developer",
                    url: makeURL("https://apple.com/developer"),
                    snippet: "Apple developer resources and documentation."
                ),
                SearchResult(
                    title: "Swift Documentation",
                    url: makeURL("https://apple.com/swift"),
                    snippet: "Official Swift programming language docs."
                )
            ]
        }

        if query.contains("site:github.com") {
            return [
                SearchResult(
                    title: "GitHub Repository",
                    url: makeURL("https://github.com/example/repo"),
                    snippet: "An example repository hosted on GitHub."
                ),
                SearchResult(
                    title: "GitHub Issues",
                    url: makeURL("https://github.com/example/repo/issues"),
                    snippet: "Issue tracker for the repository."
                )
            ]
        }

        return [
            SearchResult(
                title: "Swift Programming",
                url: makeURL("https://example.com/swift"),
                snippet: "Learn Swift programming basics and advanced topics."
            ),
            SearchResult(
                title: "Language Guide",
                url: makeURL("https://example.org/guide"),
                snippet: "A comprehensive guide to Swift language features."
            ),
            SearchResult(
                title: "Modern APIs",
                url: makeURL("https://example.net/apis"),
                snippet: "Modern Swift API usage patterns and examples."
            )
        ]
    }

    private static func makeSearchHTML(results: [SearchResult]) -> String {
        var html: String = "<html><body><div class=\"results\">"
        for result in results {
            let encodedURL: String = result.url.absoluteString.addingPercentEncoding(
                withAllowedCharacters: .urlQueryAllowed
            ) ?? result.url.absoluteString
            html += """
            <div class="result">
                <a class="result__a" href="https://duckduckgo.com/l/?uddg=\(encodedURL)">\(result.title)</a>
                <div class="result__snippet">\(result.snippet)</div>
            </div>
            """
        }
        html += "</div></body></html>"
        return html
    }

    private static func makeContentHTML(title: String, body: String) -> String {
        """
        <html>
            <head><title>\(title)</title></head>
            <body>
                <main>
                    <h1>\(title)</h1>
                    <p>\(body)</p>
                </main>
                <script>var ignored = true;</script>
                <style>.ignore { display: none; }</style>
            </body>
        </html>
        """
    }

    private static func longContent(forHost host: String) -> String {
        let base: String = "Content from \(host) describing Swift usage patterns and tooling."
        return Array(repeating: base, count: DuckDuckGoStubConstants.contentRepeatCount).joined(separator: " ")
    }
}

private final class RequestHandlerStore: @unchecked Sendable {
    private let lock: NSLock = NSLock()
    private var handler: (@Sendable (URLRequest) throws -> (HTTPURLResponse, Data))?
    private var activeSessions: Int = 0

    deinit {
        // No-op
    }

    func get() -> (@Sendable (URLRequest) throws -> (HTTPURLResponse, Data))? {
        lock.lock()
        defer { lock.unlock() }
        return handler
    }

    func set(_ handler: (@Sendable (URLRequest) throws -> (HTTPURLResponse, Data))?) {
        lock.lock()
        self.handler = handler
        lock.unlock()
    }

    func register(_ handler: @escaping @Sendable (URLRequest) throws -> (HTTPURLResponse, Data)) {
        lock.lock()
        self.handler = handler
        activeSessions += 1
        lock.unlock()
    }

    func unregister() {
        lock.lock()
        if activeSessions > 0 {
            activeSessions -= 1
        }
        if activeSessions == 0 {
            handler = nil
        }
        lock.unlock()
    }
}
