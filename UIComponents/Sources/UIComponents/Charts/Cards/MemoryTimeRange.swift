import Database
import Foundation

// MARK: - Memory Usage Supporting Types

public enum MemoryTimeRange: String, CaseIterable {
    case all = "All"
    case last10 = "Last 10"
    case last20 = "Last 20"
    case last5 = "Last 5"

    var displayName: String {
        rawValue
    }

    private enum Constants {
        static let last5Count: Int = 5
        static let last10Count: Int = 10
        static let last20Count: Int = 20
        static let maxPerformanceCount: Int = 20
    }

    func limit(_ metrics: [Metrics]) -> [Metrics] {
        switch self {
        case .last5:
            Array(metrics.suffix(Constants.last5Count))

        case .last10:
            Array(metrics.suffix(Constants.last10Count))

        case .last20:
            Array(metrics.suffix(Constants.last20Count))

        case .all:
            Array(metrics.suffix(Constants.maxPerformanceCount)) // Max 20 for performance
        }
    }
}
