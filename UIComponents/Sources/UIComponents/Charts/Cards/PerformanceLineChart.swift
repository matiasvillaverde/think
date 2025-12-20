import Database
import Foundation
import SwiftUI

/// Performance line chart supporting types and configurations
public enum PerformanceLineChart {
    public enum PerformanceMetric: String, CaseIterable, Identifiable {
        case activeMemory = "Active Memory"
        case peakMemory = "Peak Memory"
        case promptTokens = "Prompt Tokens"
        case tokensPerSecond = "Tokens/s"
        case totalTime = "Total Time"

        public var id: String { rawValue }

        public var unit: String {
            switch self {
            case .totalTime:
                "s"

            case .tokensPerSecond:
                "tok/s"

            case .activeMemory, .peakMemory:
                "MB"

            case .promptTokens:
                "tokens"
            }
        }

        public var color: Color {
            switch self {
            case .totalTime:
                .blue

            case .tokensPerSecond:
                .green

            case .activeMemory:
                .orange

            case .peakMemory:
                .red

            case .promptTokens:
                .purple
            }
        }
    }

    public enum TimeRange: String, CaseIterable {
        case all = "All"
        case last24Hours = "24 Hours"
        case last6Hours = "6 Hours"
        case last7Days = "7 Days"
        case lastHour = "1 Hour"

        func filter(_ metrics: [Metrics]) -> [Metrics] {
            let now: Date = Date()
            switch self {
            case .lastHour:
                let secondsInHour: TimeInterval = -3_600
                return metrics.filter { $0.createdAt > now.addingTimeInterval(secondsInHour) }

            case .last6Hours:
                let secondsIn6Hours: TimeInterval = -21_600
                return metrics.filter { $0.createdAt > now.addingTimeInterval(secondsIn6Hours) }

            case .last24Hours:
                let secondsIn24Hours: TimeInterval = -86_400
                return metrics.filter { $0.createdAt > now.addingTimeInterval(secondsIn24Hours) }

            case .last7Days:
                let secondsIn7Days: TimeInterval = -604_800
                return metrics.filter { $0.createdAt > now.addingTimeInterval(secondsIn7Days) }

            case .all:
                return metrics
            }
        }
    }

    public struct PerformanceData: Identifiable {
        public let id: UUID = UUID()
        public let date: Date
        public let metric: PerformanceMetric
        public let value: Double

        public init(date: Date, metric: PerformanceMetric, value: Double) {
            self.date = date
            self.metric = metric
            self.value = value
        }
    }
}
