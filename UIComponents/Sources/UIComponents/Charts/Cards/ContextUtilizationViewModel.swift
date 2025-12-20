import Database
import Foundation
import SwiftUI

// MARK: - Context Data

internal struct ContextData: Identifiable {
    let id: UUID = .init()
    let index: Int
    let label: String
    let available: Double
    let used: Double
    let date: Date

    var utilizationRate: Double {
        guard available > 0 else {
            return 0
        }
        return (used / available) * 100
    }
}

// MARK: - Context Utilization View Model

internal final class ContextUtilizationViewModel: ObservableObject {
    private let metrics: [Metrics]

    private enum Config {
        static let contextCapacity: Int = 2_048
        static let percentageMultiplier: Double = 100.0
        static let warningThreshold: Double = 80.0
        static let dangerThreshold: Double = 90.0
        static let safeThreshold: Double = 60.0
        static let formatThreshold: Double = 1
        static let bytesInKB: Double = 1_024
        static let bytesInMB: Double = 1_048_576
        static let trendMovingAvgWindow: Int = 3
    }

    init(metrics: [Metrics]) {
        self.metrics = metrics
    }

    deinit {
        // Cleanup if needed
    }

    func contextData(
        maxDataPoints: Int,
        capacityOverride: Int? = nil
    ) -> [ContextData] {
        var data: [ContextData] = []
        let capacity: Double = Double(capacityOverride ?? Config.contextCapacity)

        for (index, metric) in metrics.suffix(maxDataPoints).enumerated() {
            let used: Double = Double(metric.promptTokens + metric.generatedTokens)
            data.append(ContextData(
                index: index,
                label: "M\(index + 1)",
                available: capacity,
                used: min(used, capacity),
                date: metric.createdAt
            ))
        }

        return data
    }

    func averageUtilization(for data: [ContextData]) -> Double {
        guard !data.isEmpty else {
            return 0
        }
        let total: Double = data.map(\.utilizationRate).reduce(0, +)
        return total / Double(data.count)
    }

    func peakUtilization(for data: [ContextData]) -> Double {
        data.map(\.utilizationRate).max() ?? 0
    }

    func totalContextUsed(for data: [ContextData]) -> Double {
        data.map(\.used).reduce(0, +)
    }

    func trendDirection(for data: [ContextData]) -> TrendDirection {
        guard data.count >= Config.trendMovingAvgWindow else {
            return .stable
        }

        let recent: Double = averageUtilization(
            for: Array(data.suffix(Config.trendMovingAvgWindow))
        )
        let previous: Double = averageUtilization(
            for: Array(data.prefix(Config.trendMovingAvgWindow))
        )

        let difference: Double = recent - previous
        let changeThreshold: Double = 5.0
        if abs(difference) < changeThreshold {
            return .stable
        }
        if difference > 0 {
            return .increasing
        }
        return .decreasing
    }

    func utilizationColor(for rate: Double) -> Color {
        switch rate {
        case Config.dangerThreshold ... 100:
            .red

        case Config.warningThreshold ..< Config.dangerThreshold:
            .orange

        case Config.safeThreshold ..< Config.warningThreshold:
            .yellow

        default:
            .green
        }
    }

    func formatBytes(_ bytes: Double) -> String {
        if bytes < Config.bytesInKB {
            String(format: "%.0f B", bytes)
        } else if bytes < Config.bytesInMB {
            String(format: "%.1f KB", bytes / Config.bytesInKB)
        } else {
            String(format: "%.2f MB", bytes / Config.bytesInMB)
        }
    }

    enum TrendDirection {
        case increasing
        case decreasing
        case stable

        var icon: String {
            switch self {
            case .increasing:
                "arrow.up.right"

            case .decreasing:
                "arrow.down.right"

            case .stable:
                "arrow.right"
            }
        }

        var color: Color {
            switch self {
            case .increasing:
                .orange

            case .decreasing:
                .green

            case .stable:
                .blue
            }
        }
    }
}
