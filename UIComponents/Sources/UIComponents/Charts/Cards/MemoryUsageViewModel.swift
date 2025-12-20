import Database
import Foundation
import SwiftUI

// MARK: - Supporting Types

internal struct MemoryData: Identifiable {
    let id: UUID = .init()
    let index: Int
    let label: String
    let activeMemory: Double
    let peakMemory: Double
    let date: Date
}

// MARK: - View Model

internal final class MemoryUsageViewModel: ObservableObject {
    let metrics: [Metrics]

    private enum Constants {
        static let bytesToMB: Double = 1_048_576
        static let bytesToGB: Double = 1_024
        static let memoryThresholdMB: Double = 1_024
        static let percentageMultiplier: Double = 100
        static let zeroMemory: Double = 0
        static let metricLabelOffset: Int = 1
        static let memoryThresholdMultiplier: Double = 2
    }

    init(metrics: [Metrics]) {
        self.metrics = metrics
    }

    deinit {
        // Cleanup if needed
    }

    func memoryData(timeRange: MemoryTimeRange) -> [MemoryData] {
        let filteredMetrics: [Metrics] = timeRange.limit(metrics)

        return filteredMetrics.enumerated().map { index, metric in
            MemoryData(
                index: index,
                label: "Metric \(index + Constants.metricLabelOffset)",
                activeMemory: Double(metric.activeMemory) / Constants.bytesToMB,
                peakMemory: Double(metric.peakMemory) / Constants.bytesToMB,
                date: metric.createdAt
            )
        }
    }

    func averageMemory(for data: [MemoryData]) -> Double {
        guard !data.isEmpty else {
            return Constants.zeroMemory
        }
        return data.map(\.activeMemory).reduce(0, +) / Double(data.count)
    }

    func peakMemory(for data: [MemoryData]) -> Double {
        data.map(\.peakMemory).max() ?? Constants.zeroMemory
    }

    func memoryEfficiency(for data: [MemoryData]) -> Double {
        guard !data.isEmpty else {
            return Constants.zeroMemory
        }
        let avgActive: Double = averageMemory(for: data)
        let peak: Double = peakMemory(for: data)
        guard peak > 0 else {
            return Constants.zeroMemory
        }
        return (avgActive / peak) * Constants.percentageMultiplier
    }

    func formatMemory(_ memoryMB: Double) -> String {
        if memoryMB >= Constants.memoryThresholdMB {
            String(format: "%.1f GB", memoryMB / Constants.bytesToGB)
        } else {
            String(format: "%.0f MB", memoryMB)
        }
    }

    func memoryColor(for memoryMB: Double) -> Color {
        if memoryMB > Constants.memoryThresholdMB * Constants.memoryThresholdMultiplier {
            return .red
        }
        if memoryMB > Constants.memoryThresholdMB {
            return .orange
        }
        return .green
    }
}
