@testable import MLXSession
import Testing

@Suite("Generation analytics")
struct GenerationAnalyticsTests {
    @Test("Tokens per second avoids divide by zero")
    func tokensPerSecondAvoidsDivideByZero() {
        let info = GenerateCompletionInfo(
            promptTokenCount: 12,
            generationTokenCount: 5,
            promptTime: 0,
            generationTime: 0
        )

        #expect(info.promptTokensPerSecond == 0)
        #expect(info.tokensPerSecond == 0)
    }

    @Test("Summary includes token counts")
    func summaryIncludesTokenCounts() {
        let info = GenerateCompletionInfo(
            promptTokenCount: 12,
            generationTokenCount: 5,
            promptTime: 2.0,
            generationTime: 1.0
        )

        let summary = info.summary()
        #expect(summary.contains("Prompt:     12 tokens"))
        #expect(summary.contains("Generation: 5 tokens"))
    }
}
