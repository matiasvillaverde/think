import Testing
@testable import Abstractions

@Suite("UsageMetrics Tests")
struct UsageMetricsTests {
    @Suite("Context Utilization")
    struct ContextUtilization {
        @Test("Basic context utilization calculation")
        func testBasicContextUtilization() {
            // 50% utilization
            let halfUsed = UsageMetrics(
                generatedTokens: 100,
                totalTokens: 600,
                promptTokens: 500,
                contextWindowSize: 1000,
                contextTokensUsed: 500
            )
            #expect(halfUsed.contextUtilization == 0.5)

            // 100% utilization
            let fullyUsed = UsageMetrics(
                generatedTokens: 200,
                totalTokens: 1000,
                promptTokens: 800,
                contextWindowSize: 1000,
                contextTokensUsed: 1000
            )
            #expect(fullyUsed.contextUtilization == 1.0)

            // Missing context window size
            let noWindow = UsageMetrics(
                generatedTokens: 50,
                totalTokens: 100,
                contextTokensUsed: 50
            )
            #expect(noWindow.contextUtilization == nil)

            // Missing tokens used
            let noUsed = UsageMetrics(
                generatedTokens: 50,
                totalTokens: 100,
                contextWindowSize: 1000
            )
            #expect(noUsed.contextUtilization == nil)
        }

        @Test("Remaining context tokens calculation")
        func testRemainingContextTokens() {
            // Normal case
            let metrics = UsageMetrics(
                generatedTokens: 100,
                totalTokens: 400,
                promptTokens: 300,
                contextWindowSize: 1000,
                contextTokensUsed: 300
            )
            #expect(metrics.remainingContextTokens == 700)

            // Used exceeds window (should return 0, not negative)
            let overUsed = UsageMetrics(
                generatedTokens: 200,
                totalTokens: 1200,
                contextWindowSize: 1000,
                contextTokensUsed: 1100
            )
            #expect(overUsed.remainingContextTokens == 0)

            // Missing values
            let incomplete = UsageMetrics(
                generatedTokens: 50,
                totalTokens: 100
            )
            #expect(incomplete.remainingContextTokens == nil)
        }
    }

    @Suite("KV Cache Metrics")
    struct KVCacheMetrics {
        @Test("Average bytes per cache entry calculation")
        func testAverageBytesPerCacheEntry() {
            // Normal calculation
            let metrics = UsageMetrics(
                generatedTokens: 100,
                totalTokens: 200,
                kvCacheBytes: 1024,
                kvCacheEntries: 4
            )
            #expect(metrics.averageBytesPerCacheEntry == 256.0)

            // Zero entries should return nil
            let zeroEntries = UsageMetrics(
                generatedTokens: 50,
                totalTokens: 100,
                kvCacheBytes: 1024,
                kvCacheEntries: 0
            )
            #expect(zeroEntries.averageBytesPerCacheEntry == nil)

            // Missing cache bytes
            let noBytes = UsageMetrics(
                generatedTokens: 50,
                totalTokens: 100,
                kvCacheEntries: 10
            )
            #expect(noBytes.averageBytesPerCacheEntry == nil)

            // Missing cache entries
            let noEntries = UsageMetrics(
                generatedTokens: 50,
                totalTokens: 100,
                kvCacheBytes: 2048
            )
            #expect(noEntries.averageBytesPerCacheEntry == nil)
        }
    }
}
