import Database
import Foundation
import SwiftUI

// MARK: - Supporting Types

internal struct HeatMapCell: Identifiable, Equatable {
    let id: UUID = .init()
    let row: Int
    let column: Int
    let value: Double
    let label: String
}

internal enum HeatMapColorScheme: String, CaseIterable {
    case coolWarm = "Cool-Warm"
    case inferno = "Inferno"
    case plasma = "Plasma"
    case viridis = "Viridis"
}

// MARK: - View Model

internal final class PerplexityHeatMapViewModel: ObservableObject {
    let metrics: [Metrics]

    private enum Constants {
        static let maxRows: Int = 8
        static let maxColumns: Int = 10
        static let contextSizeMultiplier: Int = 1_000
        static let perplexityVariationMin: Double = -0.2
        static let perplexityVariationMax: Double = 0.2
        static let percentageMultiplier: Double = 100
        static let defaultEntropy: Double = 0.5
        // Color constants
        static let viridisRed1: Double = 0.267
        static let viridisRed2: Double = 0.282
        static let viridisGreen1: Double = 0.004
        static let viridisGreen2: Double = 0.914
        static let viridisBlue1: Double = 0.329
        static let viridisBlue2: Double = 0.000
        static let plasmaRed1: Double = 0.050
        static let plasmaRed2: Double = 0.940
        static let plasmaGreen1: Double = 0.029
        static let plasmaGreen2: Double = 0.975
        static let plasmaBlue1: Double = 0.527
        static let plasmaBlue2: Double = 0.131
        static let infernoRed1: Double = 0.001
        static let infernoRed2: Double = 0.988
        static let infernoGreen1: Double = 0.000
        static let infernoGreen2: Double = 1.000
        static let infernoBlue1: Double = 0.013
        static let infernoBlue2: Double = 0.644
        static let coolWarmRed1: Double = 0.230
        static let coolWarmGreen1: Double = 0.299
        static let coolWarmBlue1: Double = 0.754
        static let coolWarmGreen2: Double = 0.294
        static let colorMidpoint: Double = 0.5
        static let colorMultiplier: Double = 2
    }

    init(metrics: [Metrics]) {
        self.metrics = metrics
    }

    deinit {
        // Cleanup if needed
    }

    func heatMapData() -> [[HeatMapCell]] {
        guard !metrics.isEmpty else {
            return []
        }

        let limitedMetrics: [Metrics] = Array(metrics.suffix(Constants.maxRows))

        return limitedMetrics.enumerated().map { rowIndex, metric in
            (0..<Constants.maxColumns).map { columnIndex in
                let baseValue: Double = metric.entropy ?? Constants.defaultEntropy
                let variation: Double = Double.random(
                    in: Constants.perplexityVariationMin...Constants.perplexityVariationMax
                )
                let value: Double = max(0, min(1, baseValue + variation))

                return HeatMapCell(
                    row: rowIndex,
                    column: columnIndex,
                    value: value,
                    label: String(format: "%.2f", value)
                )
            }
        }
    }

    func colorForValue(_ value: Double, scheme: HeatMapColorScheme) -> Color {
        switch scheme {
        case .viridis:
            return viridisColor(for: value)

        case .plasma:
            return plasmaColor(for: value)

        case .inferno:
            return infernoColor(for: value)

        case .coolWarm:
            return coolWarmColor(for: value)
        }
    }

    private func viridisColor(for value: Double) -> Color {
        let normalizedValue: Double = max(0, min(1, value))
        let redDiff: Double = Constants.viridisRed2 - Constants.viridisRed1
        let greenDiff: Double = Constants.viridisGreen2 - Constants.viridisGreen1
        let blueDiff: Double = Constants.viridisBlue2 - Constants.viridisBlue1
        return Color(
            red: Constants.viridisRed1 + redDiff * normalizedValue,
            green: Constants.viridisGreen1 + greenDiff * normalizedValue,
            blue: Constants.viridisBlue1 + blueDiff * normalizedValue
        )
    }

    private func plasmaColor(for value: Double) -> Color {
        let normalizedValue: Double = max(0, min(1, value))
        let redDiff: Double = Constants.plasmaRed2 - Constants.plasmaRed1
        let greenDiff: Double = Constants.plasmaGreen2 - Constants.plasmaGreen1
        let blueDiff: Double = Constants.plasmaBlue2 - Constants.plasmaBlue1
        return Color(
            red: Constants.plasmaRed1 + redDiff * normalizedValue,
            green: Constants.plasmaGreen1 + greenDiff * normalizedValue,
            blue: Constants.plasmaBlue1 + blueDiff * normalizedValue
        )
    }

    private func infernoColor(for value: Double) -> Color {
        let normalizedValue: Double = max(0, min(1, value))
        let redDiff: Double = Constants.infernoRed2 - Constants.infernoRed1
        let greenDiff: Double = Constants.infernoGreen2 - Constants.infernoGreen1
        let blueDiff: Double = Constants.infernoBlue2 - Constants.infernoBlue1
        return Color(
            red: Constants.infernoRed1 + redDiff * normalizedValue,
            green: Constants.infernoGreen1 + greenDiff * normalizedValue,
            blue: Constants.infernoBlue1 + blueDiff * normalizedValue
        )
    }

    private func coolWarmColor(for value: Double) -> Color {
        let normalizedValue: Double = max(0, min(1, value))
        if normalizedValue < Constants.colorMidpoint {
            let localT: Double = normalizedValue * Constants.colorMultiplier
            return Color(
                red: Constants.coolWarmRed1 + (1.000 - Constants.coolWarmRed1) * localT,
                green: Constants.coolWarmGreen1 + (1.000 - Constants.coolWarmGreen1) * localT,
                blue: Constants.coolWarmBlue1 + (1.000 - Constants.coolWarmBlue1) * localT
            )
        }
        let localT: Double = (normalizedValue - Constants.colorMidpoint) * Constants.colorMultiplier
        return Color(
            red: 1.000,
            green: 1.000 - (1.000 - Constants.coolWarmGreen2) * localT,
            blue: 1.000 - 1.000 * localT
        )
    }

    func averagePerplexity(for data: [[HeatMapCell]]) -> Double {
        guard !data.isEmpty else {
            return 0
        }
        let allValues: [Double] = data.flatMap { $0.map(\.value) }
        guard !allValues.isEmpty else {
            return 0
        }
        return allValues.reduce(0, +) / Double(allValues.count)
    }

    func minPerplexity(for data: [[HeatMapCell]]) -> Double {
        data.flatMap { $0.map(\.value) }.min() ?? 0
    }

    func maxPerplexity(for data: [[HeatMapCell]]) -> Double {
        data.flatMap { $0.map(\.value) }.max() ?? 1
    }
}
