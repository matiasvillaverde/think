import Database
import Foundation
import SwiftUI

internal final class PerformanceChartViewModel: ObservableObject {
    let metrics: [Metrics]

    init(metrics: [Metrics]) {
        self.metrics = metrics
    }

    deinit {
        // Cleanup if needed
    }

    func filteredMetrics(timeRange: PerformanceLineChart.TimeRange) -> [Metrics] {
        timeRange.filter(metrics)
    }

    func performanceData(
        for selectedMetrics: Set<PerformanceLineChart.PerformanceMetric>,
        timeRange: PerformanceLineChart.TimeRange
    ) -> [PerformanceLineChart.PerformanceData] {
        var data: [PerformanceLineChart.PerformanceData] = []
        let filtered: [Metrics] = filteredMetrics(timeRange: timeRange).sorted { first, second in
            first.createdAt < second.createdAt
        }

        for metric in filtered {
            for selectedMetric in selectedMetrics {
                let value: Double = getValue(for: selectedMetric, from: metric)
                data.append(
                    PerformanceLineChart.PerformanceData(
                        date: metric.createdAt,
                        metric: selectedMetric,
                        value: value
                    )
                )
            }
        }

        return data
    }

    func getValue(
        for performanceMetric: PerformanceLineChart.PerformanceMetric,
        from metric: Metrics
    ) -> Double {
        switch performanceMetric {
        case .totalTime:
            metric.totalTime

        case .tokensPerSecond:
            metric.tokensPerSecond

        case .activeMemory:
            Double(metric.activeMemory) / Constants.memoryDivisor

        case .peakMemory:
            Double(metric.peakMemory) / Constants.memoryDivisor

        case .promptTokens:
            Double(metric.promptTokens)
        }
    }

    func getLatestValue(
        for metric: PerformanceLineChart.PerformanceMetric,
        timeRange: PerformanceLineChart.TimeRange
    ) -> Double? {
        guard let latest = filteredMetrics(timeRange: timeRange).last else {
            return nil
        }
        return getValue(for: metric, from: latest)
    }

    func formatValue(_ value: Double, unit: String) -> String {
        switch unit {
        case "s":
            String(format: "%.2f", value)

        case "tok/s":
            String(format: "%.1f", value)

        case "MB":
            String(format: "%.0f", value)

        case "tokens":
            String(format: "%.0f", value)

        default:
            String(format: "%.1f", value)
        }
    }

    private enum Constants {
        static let memoryDivisor: Double = 1_048_576
    }
}
