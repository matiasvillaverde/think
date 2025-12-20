import Foundation

extension HTTPURLResponse {
    static let successStatusCode: Int = 200
}

/// Protocol for file system operations (for testing)
internal protocol HFFileManagerProtocol: Sendable {
    func fileExists(atPath path: String) -> Bool
    func contents(atPath path: String) -> String?
    func expandTildeInPath(_ path: String) -> String
}

/// Default implementation using Foundation's FileManager
internal struct DefaultHFFileManager: HFFileManagerProtocol {
    internal func fileExists(atPath path: String) -> Bool {
        let expandedPath: String = expandTildeInPath(path)
        return FileManager.default.fileExists(atPath: expandedPath)
    }

    internal func contents(atPath path: String) -> String? {
        let expandedPath: String = expandTildeInPath(path)
        return try? String(contentsOfFile: expandedPath, encoding: .utf8)
    }

    internal func expandTildeInPath(_ path: String) -> String {
        guard path.hasPrefix("~") else { return path }

        let pathWithoutTilde: String = String(path.dropFirst())

        #if os(macOS)
        let homeDirectory: String = FileManager.default.homeDirectoryForCurrentUser.path
        #else
        // On iOS and visionOS, use the Documents directory's parent as home
        let homeDirectory: String = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
            .first?
            .deletingLastPathComponent()
            .path ?? NSHomeDirectory()
        #endif

        if pathWithoutTilde.isEmpty || pathWithoutTilde.hasPrefix("/") {
            return homeDirectory + pathWithoutTilde
        }
        return homeDirectory + "/" + pathWithoutTilde
    }
}

/// Protocol for HTTP client operations (for testing)
internal protocol HTTPClientProtocol: Sendable {
    func get(url: URL, headers: [String: String]) async throws -> HTTPClientResponse
    func head(url: URL, headers: [String: String]) async throws -> HTTPClientResponse
}

/// HTTP response structure
internal struct HTTPClientResponse: Sendable {
    internal let data: Data
    internal let statusCode: Int
    internal let headers: [String: String]

    internal init(data: Data, statusCode: Int, headers: [String: String] = [:]) {
        self.data = data
        self.statusCode = statusCode
        self.headers = headers
    }
}

/// Manager for HuggingFace authentication tokens
/// 
/// Handles token discovery from multiple sources following the same priority 
/// as the original HUB implementation:
/// 1. HF_TOKEN environment variable
/// 2. HUGGING_FACE_HUB_TOKEN environment variable  
/// 3. HF_TOKEN_PATH file content
/// 4. HF_HOME/token file content
/// 5. ~/.cache/huggingface/token file content
/// 6. ~/.huggingface/token file content
internal actor HFTokenManager {
    private let environment: [String: String]
    private let fileManager: HFFileManagerProtocol
    private let httpClient: HTTPClientProtocol
    private var cachedToken: String?
    private let logger: ModelDownloaderLogger

    /// Initialize HFTokenManager with optional dependencies for testing
    internal init(
        environment: [String: String] = ProcessInfo.processInfo.environment,
        fileManager: HFFileManagerProtocol = DefaultHFFileManager(),
        httpClient: HTTPClientProtocol = DefaultHTTPClient()
    ) {
        self.environment = environment
        self.fileManager = fileManager
        self.httpClient = httpClient
        self.logger = ModelDownloaderLogger(
            subsystem: "com.think.modeldownloader",
            category: "HFTokenManager"
        )
    }

    /// Get the HuggingFace token from various sources
    /// Returns nil if no token is found or all tokens are empty
    internal func getToken() -> String? {
        if let cached = cachedToken {
            Task {
                await logger.debug("Using cached token")
            }
            return cached
        }

        Task {
            await logger.debug("Searching for HuggingFace token")
        }

        let possibleTokenSources: [(name: String, source: () -> String?)] = [
            ("HF_TOKEN environment variable", { self.environment["HF_TOKEN"] }),
            ("HUGGING_FACE_HUB_TOKEN environment variable", { self.environment["HUGGING_FACE_HUB_TOKEN"] }),
            ("HF_TOKEN_PATH file", { self.tokenFromPath() }),
            ("HF_HOME/token file", { self.tokenFromHFHome() }),
            ("~/.cache/huggingface/token file", { self.tokenFromCacheLocation() }),
            ("~/.huggingface/token file", { self.tokenFromHuggingFaceHome() })
        ]

        for (name, tokenSource) in possibleTokenSources {
            if let token = tokenSource(), !token.isEmpty {
                Task {
                    await logger.info("Found token", metadata: ["source": name])
                }
                cachedToken = token
                return token
            }
        }

        Task {
            await logger.debug("No HuggingFace token found")
        }
        return nil
    }

    /// Validate the current token by calling the whoami API
    /// Throws HuggingFaceError.authenticationRequired if no token or invalid token
    internal func whoami() async throws -> Config {
        guard let token = getToken() else {
            await logger.error("No token available for whoami request")
            throw HuggingFaceError.authenticationRequired
        }

        guard let url: URL = URL(string: "https://huggingface.co/api/whoami-v2") else {
            await logger.error("Invalid whoami URL")
            throw HuggingFaceError.invalidResponse
        }

        await logger.debug("Validating token with whoami API")

        let headers: [String: String] = ["Authorization": "Bearer \(token)"]
        let response: HTTPClientResponse = try await httpClient.get(url: url, headers: headers)

        guard response.statusCode == HTTPURLResponse.successStatusCode else {
            await logger.error("Token validation failed", metadata: ["statusCode": response.statusCode])
            throw HuggingFaceError.authenticationRequired
        }

        let json: Any = try JSONSerialization.jsonObject(with: response.data, options: [])
        guard let dictionary = json as? [String: Any] else {
            await logger.error("Invalid JSON response from whoami API")
            throw HuggingFaceError.invalidResponse
        }

        await logger.info("Token validated successfully")
        return Config(dictionary)
    }

    // MARK: - Private Token Discovery Methods

    private func tokenFromPath() -> String? {
        guard let tokenPath = environment["HF_TOKEN_PATH"] else {
            return nil
        }
        let expandedPath: String = fileManager.expandTildeInPath(tokenPath)
        return fileManager.contents(atPath: expandedPath)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func tokenFromHFHome() -> String? {
        guard let hfHome = environment["HF_HOME"] else {
            return nil
        }
        let tokenPath: String = "\(hfHome)/token"
        let expandedPath: String = fileManager.expandTildeInPath(tokenPath)
        return fileManager.contents(atPath: expandedPath)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func tokenFromCacheLocation() -> String? {
        let tokenPath: String = "~/.cache/huggingface/token"
        return fileManager.contents(atPath: tokenPath)?.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func tokenFromHuggingFaceHome() -> String? {
        let tokenPath: String = "~/.huggingface/token"
        return fileManager.contents(atPath: tokenPath)?.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

/// Default HTTP client implementation
internal struct DefaultHTTPClient: HTTPClientProtocol {
    private let urlSession: URLSession

    internal init(urlSession: URLSession = .shared) {
        self.urlSession = urlSession
    }

    internal func get(url: URL, headers: [String: String]) async throws -> HTTPClientResponse {
        var request: URLRequest = URLRequest(url: url)
        for (key, value) in headers {
            request.setValue(value, forHTTPHeaderField: key)
        }

        let (data, response): (Data, URLResponse) = try await urlSession.data(for: request)

        guard let httpResponse: HTTPURLResponse = response as? HTTPURLResponse else {
            throw HuggingFaceError.invalidResponse
        }

        let responseHeaders: [String: String] = httpResponse.allHeaderFields
            .reduce(into: [String: String]()) { result, item in
            if let key = item.key as? String, let value = item.value as? String {
                result[key] = value
            }
            }

        return HTTPClientResponse(
            data: data,
            statusCode: httpResponse.statusCode,
            headers: responseHeaders
        )
    }

    internal func head(url: URL, headers: [String: String]) async throws -> HTTPClientResponse {
        var request: URLRequest = URLRequest(url: url)
        request.httpMethod = "HEAD"
        for (key, value) in headers {
            request.setValue(value, forHTTPHeaderField: key)
        }

        let (data, response): (Data, URLResponse) = try await urlSession.data(for: request)

        guard let httpResponse: HTTPURLResponse = response as? HTTPURLResponse else {
            throw HuggingFaceError.invalidResponse
        }

        let responseHeaders: [String: String] = httpResponse.allHeaderFields
            .reduce(into: [String: String]()) { result, item in
            if let key = item.key as? String, let value = item.value as? String {
                result[key] = value
            }
            }

        return HTTPClientResponse(
            data: data,
            statusCode: httpResponse.statusCode,
            headers: responseHeaders
        )
    }
}
