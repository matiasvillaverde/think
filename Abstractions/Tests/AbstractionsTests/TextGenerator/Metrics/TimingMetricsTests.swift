import Testing
import Foundation
@testable import Abstractions

@Suite("TimingMetrics Tests")
struct TimingMetricsTests {
    @Suite("Percentile Calculations")
    struct PercentileCalculations {
        @Test("Basic percentile calculation with known values")
        func testBasicPercentileCalculation() {
            let tokenTimings: [Duration] = [
                .milliseconds(100),
                .milliseconds(200),
                .milliseconds(300),
                .milliseconds(400),
                .milliseconds(500)
            ]

            let metrics = TimingMetrics(
                totalTime: .seconds(1),
                tokenTimings: tokenTimings
            )

            // Test median (50th percentile)
            let median = metrics.percentile(0.5)
            #expect(median == .milliseconds(300))

            // Test 95th percentile - with 5 elements, index calculation gives us element at index 3 (400ms)
            let p95 = metrics.percentile(0.95)
            #expect(p95 == .milliseconds(400))

            // Test 99th percentile - with 5 elements, index calculation gives us element at index 3 (400ms)
            let p99 = metrics.percentile(0.99)
            #expect(p99 == .milliseconds(400))

            // Test convenience properties
            #expect(metrics.medianTimePerToken == .milliseconds(300))
            #expect(metrics.p95TimePerToken == .milliseconds(400))
            #expect(metrics.p99TimePerToken == .milliseconds(400))
        }

        @Test("Edge cases for percentile calculations")
        func testPercentileEdgeCases() {
            // Single token timing
            let singleTiming = TimingMetrics(
                totalTime: .milliseconds(100),
                tokenTimings: [.milliseconds(100)]
            )
            #expect(singleTiming.percentile(0.5) == .milliseconds(100))
            #expect(singleTiming.percentile(0.95) == .milliseconds(100))
            #expect(singleTiming.percentile(0.99) == .milliseconds(100))

            // Empty timings
            let emptyTiming = TimingMetrics(
                totalTime: .milliseconds(100),
                tokenTimings: []
            )
            #expect(emptyTiming.percentile(0.5) == nil)
            #expect(emptyTiming.percentile(0.95) == nil)
            #expect(emptyTiming.medianTimePerToken == nil)

            // Invalid percentile values
            let metrics = TimingMetrics(
                totalTime: .seconds(1),
                tokenTimings: [.milliseconds(100), .milliseconds(200)]
            )
            #expect(metrics.percentile(-0.1) == nil)
            #expect(metrics.percentile(1.5) == nil)
        }
    }

    @Suite("Average Time Computations")
    struct AverageTimeComputations {
        @Test("Average time per token calculation")
        func testAverageTimePerToken() {
            // Known timings that should average to 200ms
            let metrics = TimingMetrics(
                totalTime: .milliseconds(600),
                tokenTimings: [
                    .milliseconds(100),
                    .milliseconds(200),
                    .milliseconds(300)
                ]
            )

            let average = metrics.averageTimePerToken
            #expect(average == .milliseconds(200))

            // Empty timings should return nil
            let emptyMetrics = TimingMetrics(
                totalTime: .milliseconds(100),
                tokenTimings: []
            )
            #expect(emptyMetrics.averageTimePerToken == nil)
        }

        @Test("Tokens per second calculation")
        func testTokensPerSecond() {
            // With token timings
            let metricsWithTimings = TimingMetrics(
                totalTime: .seconds(2),
                tokenTimings: Array(repeating: .milliseconds(200), count: 10)
            )
            let tps = metricsWithTimings.tokensPerSecond
            #expect(tps == 5.0) // 10 tokens in 2 seconds = 5 TPS

            // With external token count
            let metricsNoTimings = TimingMetrics(
                totalTime: .seconds(4),
                tokenTimings: []
            )
            let externalTps = metricsNoTimings.tokensPerSecond(tokenCount: 20)
            #expect(externalTps == 5.0) // 20 tokens in 4 seconds = 5 TPS

            // Zero duration edge case
            let zeroMetrics = TimingMetrics(
                totalTime: .zero,
                tokenTimings: [.milliseconds(100)]
            )
            #expect(zeroMetrics.tokensPerSecond == nil)

            // Zero token count
            let noTokenMetrics = TimingMetrics(
                totalTime: .seconds(1),
                tokenTimings: []
            )
            #expect(noTokenMetrics.tokensPerSecond(tokenCount: 0) == nil)
        }
    }
}
