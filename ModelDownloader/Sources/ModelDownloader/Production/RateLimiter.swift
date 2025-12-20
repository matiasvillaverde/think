import Foundation

/// Rate limiter for API requests
internal actor RateLimiter {
    private let requestsPerMinute: Int
    private let burstSize: Int
    private var tokens: Double
    private var lastRefill: Date
    private let persistenceKey: String?
    private let logger: ModelDownloaderLogger = ModelDownloaderLogger(
        subsystem: "com.think.modeldownloader",
        category: "RateLimiter"
    )

    /// Initialize rate limiter
    /// - Parameters:
    ///   - requestsPerMinute: Maximum requests per minute
    ///   - burstSize: Maximum burst capacity
    ///   - persistenceKey: Optional UserDefaults key for persistence
    internal init(
        requestsPerMinute: Int = 300,
        burstSize: Int = 50,
        persistenceKey: String? = nil
    ) {
        self.requestsPerMinute = requestsPerMinute
        self.burstSize = burstSize
        self.persistenceKey = persistenceKey

        // Try to restore state if persistence is enabled
        if let key = persistenceKey,
           let savedState = UserDefaults.standard.dictionary(forKey: key),
           let savedTokens = savedState["tokens"] as? Double,
           let savedTimestamp = savedState["lastRefill"] as? TimeInterval {
            // Initialize with saved state
            self.tokens = savedTokens
            self.lastRefill = Date(timeIntervalSince1970: savedTimestamp)

            // Immediately refill based on elapsed time
            let now: Date = Date()
            let elapsed: TimeInterval = now.timeIntervalSince(lastRefill)
            let refillRate: Double = Double(requestsPerMinute) / 60.0
            let tokensToAdd: Double = elapsed * refillRate
            self.tokens = min(Double(burstSize), tokens + tokensToAdd)
            self.lastRefill = now
        } else {
            // No saved state, initialize normally
            self.tokens = Double(burstSize)
            self.lastRefill = Date()
        }
    }

    /// Wait if rate limit would be exceeded
    internal func waitIfNeeded() async throws {
        // Refill tokens based on time elapsed
        refillTokens()

        // If we have tokens, consume one and proceed
        if tokens >= 1.0 {
            tokens -= 1.0
            saveStateIfNeeded()
            return
        }

        // Calculate wait time for next token
        let refillRate: Double = Double(requestsPerMinute) / 60.0 // tokens per second
        let waitTime: Double = (1.0 - tokens) / refillRate

        await logger.debug("Rate limit reached, waiting \(waitTime)s")

        // Wait for token to be available
        try await Task.sleep(nanoseconds: UInt64(waitTime * 1_000_000_000))

        // Refill and consume token
        refillTokens()
        tokens -= 1.0
        saveStateIfNeeded()
    }

    /// Check if request can proceed without waiting
    internal func canProceed() -> Bool {
        refillTokens()
        return tokens >= 1.0
    }

    /// Get current token count
    internal func getCurrentTokens() -> Double {
        refillTokens()
        return tokens
    }

    // MARK: - Private Helpers

    private func refillTokens() {
        let now: Date = Date()
        let elapsed: TimeInterval = now.timeIntervalSince(lastRefill)

        // Calculate tokens to add based on elapsed time
        let refillRate: Double = Double(requestsPerMinute) / 60.0 // tokens per second
        let tokensToAdd: Double = elapsed * refillRate

        // Add tokens up to burst capacity
        tokens = min(Double(burstSize), tokens + tokensToAdd)
        lastRefill = now
    }

    private func saveStateIfNeeded() {
        guard let key = persistenceKey else { return }

        let state: [String: Any] = [
            "tokens": tokens,
            "lastRefill": lastRefill.timeIntervalSince1970
        ]
        UserDefaults.standard.set(state, forKey: key)
    }
}

/// Rate limiter for HuggingFace API
internal actor HuggingFaceRateLimiter {
    private let authenticated: RateLimiter
    private let unauthenticated: RateLimiter
    private let logger: ModelDownloaderLogger = ModelDownloaderLogger(
        subsystem: "com.modeldownloader",
        category: "hf-ratelimit"
    )

    internal init(enablePersistence: Bool = true) {
        // HuggingFace rate limits (approximate)
        self.authenticated = RateLimiter(
            requestsPerMinute: 300,
            burstSize: 50,
            persistenceKey: enablePersistence ? "com.modeldownloader.hf.ratelimiter.authenticated" : nil
        )
        self.unauthenticated = RateLimiter(
            requestsPerMinute: 60,
            burstSize: 10,
            persistenceKey: enablePersistence ? "com.modeldownloader.hf.ratelimiter.unauthenticated" : nil
        )
    }

    /// Wait if needed based on authentication status
    /// - Parameter isAuthenticated: Whether request is authenticated
    internal func waitIfNeeded(isAuthenticated: Bool) async throws {
        let limiter: RateLimiter = isAuthenticated ? authenticated : unauthenticated
        try await limiter.waitIfNeeded()
    }

    /// Log rate limit status
    internal func logStatus(isAuthenticated: Bool) async {
        let limiter: RateLimiter = isAuthenticated ? authenticated : unauthenticated
        let tokens: Double = await limiter.getCurrentTokens()

        await logger.debug(
            "Rate limit status",
            metadata: [
                "authenticated": isAuthenticated,
                "availableTokens": tokens
            ]
        )
    }
}

/// Extension to add rate limiting to HubAPI
extension HubAPI {
    /// Create HubAPI with rate limiting
    static func withRateLimiting(
        endpoint: String = "https://huggingface.co",
        httpClient: (any HTTPClientProtocol)? = nil,
        tokenManager: HFTokenManager? = nil
    ) -> HubAPI {
        let rateLimiter: HuggingFaceRateLimiter = HuggingFaceRateLimiter()

        // Wrap HTTP client with rate limiting
        let wrappedClient: RateLimitedHTTPClient = RateLimitedHTTPClient(
            underlying: httpClient ?? DefaultHTTPClient(),
            rateLimiter: rateLimiter,
            tokenManager: tokenManager
        )

        return HubAPI(
            endpoint: endpoint,
            httpClient: wrappedClient,
            tokenManager: tokenManager
        )
    }
}

/// HTTP client wrapper that adds rate limiting
private actor RateLimitedHTTPClient: HTTPClientProtocol {
    private let underlying: any HTTPClientProtocol
    private let rateLimiter: HuggingFaceRateLimiter
    private let tokenManager: HFTokenManager?

    init(
        underlying: any HTTPClientProtocol,
        rateLimiter: HuggingFaceRateLimiter,
        tokenManager: HFTokenManager?
    ) {
        self.underlying = underlying
        self.rateLimiter = rateLimiter
        self.tokenManager = tokenManager
    }

    func get(url: URL, headers: [String: String]) async throws -> HTTPClientResponse {
        // Check if request is authenticated
        let hasAuthHeader: Bool = headers["Authorization"] != nil
        let hasToken: Bool = await tokenManager?.getToken() != nil
        let isAuthenticated: Bool = hasAuthHeader || hasToken

        // Apply rate limiting
        try await rateLimiter.waitIfNeeded(isAuthenticated: isAuthenticated)

        // Make request
        return try await underlying.get(url: url, headers: headers)
    }

    func head(url: URL, headers: [String: String]) async throws -> HTTPClientResponse {
        // Check if request is authenticated
        let hasAuthHeader: Bool = headers["Authorization"] != nil
        let hasToken: Bool = await tokenManager?.getToken() != nil
        let isAuthenticated: Bool = hasAuthHeader || hasToken

        // Apply rate limiting
        try await rateLimiter.waitIfNeeded(isAuthenticated: isAuthenticated)

        // Make request
        return try await underlying.head(url: url, headers: headers)
    }
}
