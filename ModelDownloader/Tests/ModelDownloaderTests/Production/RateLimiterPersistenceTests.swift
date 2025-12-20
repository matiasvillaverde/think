import Foundation
@testable import ModelDownloader
import Testing

// MARK: - RateLimiter Persistence Tests

@Test("RateLimiter should persist state across instances")
internal func testRateLimiterStatePersistence() async throws {
    // Create a custom UserDefaults for testing
    let suiteName: String = "com.test.ratelimiter"
    let testDefaults: UserDefaults = UserDefaults(suiteName: suiteName)!
    defer {
        testDefaults.removePersistentDomain(forName: suiteName)
        testDefaults.synchronize()
    }

    // Create first rate limiter instance
    let limiter1: PersistentRateLimiter = PersistentRateLimiter(
        requestsPerMinute: 60,
        burstSize: 10,
        suiteName: suiteName,
        key: "test.limiter"
    )

    // Consume some tokens
    for _: Int in 0..<5 {
        try await limiter1.waitIfNeeded()
    }

    // Check remaining tokens
    let tokensAfterConsumption: Double = await limiter1.getCurrentTokens()
    let maxTokens: Double = 10.0
    #expect(tokensAfterConsumption < maxTokens)
    let minTokens: Double = 5.0
    #expect(tokensAfterConsumption >= minTokens)

    // Create a new instance with same key
    let limiter2: PersistentRateLimiter = PersistentRateLimiter(
        requestsPerMinute: 60,
        burstSize: 10,
        suiteName: suiteName,
        key: "test.limiter"
    )

    // Should restore state from first instance
    let restoredTokens: Double = await limiter2.getCurrentTokens()
    #expect(abs(restoredTokens - tokensAfterConsumption) < 2.0) // Allow small time-based refill
}

@Test("RateLimiter should handle missing persisted state")
internal func testRateLimiterMissingState() async {
    let suiteName: String = "com.test.ratelimiter.missing"
    let testDefaults: UserDefaults = UserDefaults(suiteName: suiteName)!
    defer {
        testDefaults.removePersistentDomain(forName: suiteName)
        testDefaults.synchronize()
    }

    // Create rate limiter with no existing state
    let limiter: PersistentRateLimiter = PersistentRateLimiter(
        requestsPerMinute: 120,
        burstSize: 20,
        suiteName: suiteName,
        key: "test.missing"
    )

    // Should start with full burst capacity
    let initialTokens: Double = await limiter.getCurrentTokens()
    let expectedInitialTokens: Double = 20.0
    #expect(initialTokens == expectedInitialTokens)
}

@Test("RateLimiter should persist state after each request")
internal func testRateLimiterPersistsAfterEachRequest() async throws {
    let suiteName: String = "com.test.ratelimiter.continuous"
    let testDefaults: UserDefaults = UserDefaults(suiteName: suiteName)!
    defer {
        testDefaults.removePersistentDomain(forName: suiteName)
        testDefaults.synchronize()
    }

    let limiter: PersistentRateLimiter = PersistentRateLimiter(
        requestsPerMinute: 60,
        burstSize: 10,
        suiteName: suiteName,
        key: "test.continuous"
    )

    // Consume tokens one by one
    for step: Int in 1...3 {
        try await limiter.waitIfNeeded()

        // Create new instance to verify persistence
        let verifyLimiter: PersistentRateLimiter = PersistentRateLimiter(
            requestsPerMinute: 60,
            burstSize: 10,
            suiteName: suiteName,
            key: "test.continuous"
        )

        let tokens: Double = await verifyLimiter.getCurrentTokens()
        #expect(tokens <= Double(10 - step) + 1.0) // Allow for some refill
    }
}

@Test("HuggingFaceRateLimiter should persist both authenticated and unauthenticated states")
internal func testHuggingFaceRateLimiterPersistence() async throws {
    let suiteName: String = "com.test.hf.ratelimiter"
    let testDefaults: UserDefaults = UserDefaults(suiteName: suiteName)!
    defer {
        testDefaults.removePersistentDomain(forName: suiteName)
        testDefaults.synchronize()
    }

    // Create first instance
    let limiter1: PersistentHuggingFaceRateLimiter = PersistentHuggingFaceRateLimiter(suiteName: suiteName)

    // Consume tokens from both limiters
    try await limiter1.waitIfNeeded(isAuthenticated: true)
    try await limiter1.waitIfNeeded(isAuthenticated: true)
    try await limiter1.waitIfNeeded(isAuthenticated: false)

    // Create second instance
    let limiter2: PersistentHuggingFaceRateLimiter = PersistentHuggingFaceRateLimiter(suiteName: suiteName)

    // Check that state was restored
    let authTokens: Double = await limiter2.getAuthenticatedTokens()
    let unauthTokens: Double = await limiter2.getUnauthenticatedTokens()

    let maxAuthTokens: Double = 50.0
    #expect(authTokens < maxAuthTokens) // Less than burst size
    let maxUnauthTokens: Double = 10.0
    #expect(unauthTokens < maxUnauthTokens) // Less than burst size
}

// MARK: - Mock Persistent Rate Limiter

/// Rate limiter that persists its state to UserDefaults
internal actor PersistentRateLimiter {
    private let requestsPerMinute: Int
    private let burstSize: Int
    private var tokens: Double
    private var lastRefill: Date
    private let persistenceKey: String
    private let suiteName: String?

    internal init(
        requestsPerMinute: Int = 300,
        burstSize: Int = 50,
        suiteName: String? = nil,
        key: String = "com.modeldownloader.ratelimiter"
    ) {
        self.requestsPerMinute = requestsPerMinute
        self.burstSize = burstSize
        self.suiteName = suiteName
        self.persistenceKey = key

        // Try to restore state from UserDefaults
        let userDefaults: UserDefaults? = suiteName != nil ? UserDefaults(suiteName: suiteName!) : UserDefaults.standard
        if let savedState: [String: Any] = userDefaults?.dictionary(forKey: persistenceKey),
           let savedTokens: Double = savedState["tokens"] as? Double,
           let savedTimestamp: TimeInterval = savedState["lastRefill"] as? TimeInterval {
            // Initialize with saved state
            self.tokens = savedTokens
            self.lastRefill = Date(timeIntervalSince1970: savedTimestamp)

            // Refill tokens based on time elapsed since save
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

    internal func waitIfNeeded() async throws {
        refillTokens()

        if tokens >= 1.0 {
            tokens -= 1.0
            saveState()
            return
        }

        let refillRate: Double = Double(requestsPerMinute) / 60.0
        let waitTime: Double = (1.0 - tokens) / refillRate

        try await Task.sleep(nanoseconds: UInt64(waitTime * 1_000_000_000))

        refillTokens()
        tokens -= 1.0
        saveState()
    }

    internal func getCurrentTokens() -> Double {
        refillTokens()
        return tokens
    }

    private func refillTokens() {
        let now: Date = Date()
        let elapsed: TimeInterval = now.timeIntervalSince(lastRefill)
        let refillRate: Double = Double(requestsPerMinute) / 60.0
        let tokensToAdd: Double = elapsed * refillRate
        tokens = min(Double(burstSize), tokens + tokensToAdd)
        lastRefill = now
    }

    private func saveState() {
        let userDefaults: UserDefaults? = suiteName != nil ? UserDefaults(suiteName: suiteName!) : UserDefaults.standard
        let state: [String: Any] = [
            "tokens": tokens,
            "lastRefill": lastRefill.timeIntervalSince1970
        ]
        userDefaults?.set(state, forKey: persistenceKey)
        userDefaults?.synchronize()
    }
}

/// Persistent version of HuggingFaceRateLimiter
internal actor PersistentHuggingFaceRateLimiter {
    private let authenticated: PersistentRateLimiter
    private let unauthenticated: PersistentRateLimiter

    internal init(suiteName: String? = nil) {
        self.authenticated = PersistentRateLimiter(
            requestsPerMinute: 300,
            burstSize: 50,
            suiteName: suiteName,
            key: "com.modeldownloader.hf.authenticated"
        )
        self.unauthenticated = PersistentRateLimiter(
            requestsPerMinute: 60,
            burstSize: 10,
            suiteName: suiteName,
            key: "com.modeldownloader.hf.unauthenticated"
        )
    }

    internal func waitIfNeeded(isAuthenticated: Bool) async throws {
        let limiter: PersistentRateLimiter = isAuthenticated ? authenticated : unauthenticated
        try await limiter.waitIfNeeded()
    }

    internal func getAuthenticatedTokens() async -> Double {
        await authenticated.getCurrentTokens()
    }

    internal func getUnauthenticatedTokens() async -> Double {
        await unauthenticated.getCurrentTokens()
    }
}
