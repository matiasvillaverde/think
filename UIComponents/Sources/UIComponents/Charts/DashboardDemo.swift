import Database
import SwiftUI

/// Demo view showing how to use the new List-based dashboard
public struct DashboardDemo: View {
    @State private var metrics: [Metrics] = generateSampleMetrics()

    private enum Constants {
        static let sampleCount: Int = 20
        static let modelCount: Int = 3
        static let minTotalTime: Double = 0.5
        static let maxTotalTime: Double = 5.0
        static let minTokensPerSecond: Double = 10.0
        static let maxTokensPerSecond: Double = 100.0
        static let minPromptTokens: Int = 100
        static let maxPromptTokens: Int = 1_000
        static let minGeneratedTokens: Int = 50
        static let maxGeneratedTokens: Int = 500
        static let minTotalTokens: Int = 150
        static let maxTotalTokens: Int = 1_500
        static let minTimeToFirstToken: Double = 0.1
        static let maxTimeToFirstToken: Double = 1.0
        static let minActiveMemory: UInt64 = 100_000_000
        static let maxActiveMemory: UInt64 = 500_000_000
        static let minPeakMemory: UInt64 = 200_000_000
        static let maxPeakMemory: UInt64 = 600_000_000
        static let minContextTokens: Int = 1_000
        static let maxContextTokens: Int = 4_000
        static let maxContextTokensLimit: Int = 4_096
        static let minPerplexity: Double = 1.0
        static let maxPerplexity: Double = 10.0
        static let minEntropy: Double = 0.5
        static let maxEntropy: Double = 2.0
        static let minRepetitionRate: Double = 0.1
        static let maxRepetitionRate: Double = 0.5
        static let minContextUtilization: Double = 0.3
        static let maxContextUtilization: Double = 0.9
        static let hoursOffset: Int = 3_600
    }

    public init() {
        // Required for public struct
    }

    public var body: some View {
        NavigationStack {
            ModelDashboardList(metrics: $metrics)
        }
    }

    // Generate sample data for demonstration
    private static func generateSampleMetrics() -> [Metrics] {
        var metrics: [Metrics] = []
        let models: [String] = ["GPT-4", "Claude", "Llama"]

        for index in 0 ..< Constants.sampleCount {
            let promptTokens: Int = Int.random(
                in: Constants.minPromptTokens ... Constants.maxPromptTokens
            )
            let generatedTokens: Int = Int.random(
                in: Constants.minGeneratedTokens ... Constants.maxGeneratedTokens
            )

            let metric: Metrics = Metrics(
                totalTime: Double.random(
                    in: Constants.minTotalTime ... Constants.maxTotalTime
                ),
                timeToFirstToken: Double.random(
                    in: Constants.minTimeToFirstToken ... Constants.maxTimeToFirstToken
                ),
                promptTokens: promptTokens,
                generatedTokens: generatedTokens,
                totalTokens: promptTokens + generatedTokens,
                contextWindowSize: Constants.maxContextTokensLimit,
                contextTokensUsed: Int.random(
                    in: Constants.minContextTokens ... Constants.maxContextTokens
                ),
                activeMemory: UInt64.random(
                    in: Constants.minActiveMemory ... Constants.maxActiveMemory
                ),
                peakMemory: UInt64.random(
                    in: Constants.minPeakMemory ... Constants.maxPeakMemory
                ),
                perplexity: Double.random(
                    in: Constants.minPerplexity ... Constants.maxPerplexity
                ),
                entropy: Double.random(
                    in: Constants.minEntropy ... Constants.maxEntropy
                ),
                repetitionRate: Double.random(
                    in: Constants.minRepetitionRate ... Constants.maxRepetitionRate
                ),
                contextUtilization: Double.random(
                    in: Constants.minContextUtilization ... Constants.maxContextUtilization
                ),
                modelName: models[index % Constants.modelCount]
            )
            metrics.append(metric)
        }

        return metrics
    }
}

// MARK: - Preview

/// Preview provider for DashboardDemo
public struct DashboardDemo_Previews: PreviewProvider {
    public static var previews: some View {
        DashboardDemo()
    }
}
