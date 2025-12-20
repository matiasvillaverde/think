import Foundation
import SwiftData

extension Metrics {
    public static func preview(
        totalTime: TimeInterval? = nil,
        timeToFirstToken: TimeInterval? = nil,
        promptTokens: Int? = nil,
        generatedTokens: Int? = nil,
        totalTokens: Int? = nil,
        contextWindowSize: Int? = nil,
        contextTokensUsed: Int? = nil,
        peakMemory: UInt64? = nil,
        perplexity: Double? = nil,
        entropy: Double? = nil,
        repetitionRate: Double? = nil,
        contextUtilization: Double? = nil,
        modelName: String? = nil,
        timeToFirstTokenP50: Double? = nil,
        timeToFirstTokenP95: Double? = nil,
        timeToFirstTokenP99: Double? = nil,
        createdAt: Date = Date()
    ) -> Metrics {
        let metrics = Metrics(
            totalTime: totalTime ?? 2.5,
            timeToFirstToken: timeToFirstToken ?? 0.15,
            promptTokens: promptTokens ?? 500,
            generatedTokens: generatedTokens ?? 1500,
            totalTokens: totalTokens ?? 2000,
            contextWindowSize: contextWindowSize ?? 4096,
            contextTokensUsed: contextTokensUsed ?? 2000,
            peakMemory: peakMemory ?? 52_428_800,
            perplexity: perplexity,
            entropy: entropy,
            repetitionRate: repetitionRate,
            contextUtilization: contextUtilization,
            modelName: modelName,
            timeToFirstTokenP50: timeToFirstTokenP50,
            timeToFirstTokenP95: timeToFirstTokenP95,
            timeToFirstTokenP99: timeToFirstTokenP99
        )
        
        return metrics
    }
}