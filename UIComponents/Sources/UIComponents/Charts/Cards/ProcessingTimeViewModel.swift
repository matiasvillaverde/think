import Database
import Foundation
import SwiftUI

// MARK: - Processing Component

internal struct ProcessingComponent: Identifiable {
    let id: UUID = .init()
    let name: String
    let value: Double
    let color: Color
    let type: ComponentType

    enum ComponentType {
        case inference
        case postProcessing
        case tokenization
    }
}

// MARK: - Processing Data

internal struct ProcessingData: Identifiable {
    let id: String
    let label: String
    let components: [ProcessingComponent]
    let total: Double

    func percentage(for component: ProcessingComponent) -> Double {
        guard total > 0 else {
            return 0
        }
        return (component.value / total) * 100
    }
}

// MARK: - Processing Time View Model

internal final class ProcessingTimeViewModel: ObservableObject {
    private let metrics: [Metrics]

    private enum Config {
        static let tokenizationRatio: Double = 0.15
        static let postProcessingRatio: Double = 0.10
        static let percentageMultiplier: Double = 100.0
        static let prefixLength: Int = 6
        static let formatThreshold: Double = 1
        static let millisecondsThreshold: Double = 1_000
    }

    init(metrics: [Metrics]) {
        self.metrics = metrics
    }

    deinit {
        // Cleanup if needed
    }

    func processingData(maxItems: Int, sortOrder: ProcessingSortOrder) -> [ProcessingData] {
        var data: [ProcessingData] = []

        for metric in metrics.suffix(maxItems) {
            let infer: Double = metric.timeToFirstToken ?? 0
            let token: Double = infer * Config.tokenizationRatio
            let post: Double = infer * Config.postProcessingRatio
            let total: Double = infer + token + post

            let components: [ProcessingComponent] = [
                ProcessingComponent(
                    name: "Inference",
                    value: infer,
                    color: .blue,
                    type: .inference
                ),
                ProcessingComponent(
                    name: "Tokenization",
                    value: token,
                    color: .green,
                    type: .tokenization
                ),
                ProcessingComponent(
                    name: "Post-processing",
                    value: post,
                    color: .orange,
                    type: .postProcessing
                )
            ]

            data.append(ProcessingData(
                id: metric.id.uuidString,
                label: abbreviatedLabel(from: metric.id.uuidString),
                components: components,
                total: total
            ))
        }

        return sortedData(data, by: sortOrder)
    }

    func totalProcessingTime(for data: [ProcessingData]) -> Double {
        data.map(\.total).reduce(0, +)
    }

    func averageProcessingTime(for data: [ProcessingData]) -> Double {
        guard !data.isEmpty else {
            return 0
        }
        return totalProcessingTime(for: data) / Double(data.count)
    }

    func formatTime(_ milliseconds: Double) -> String {
        if milliseconds < Config.formatThreshold {
            String(format: "%.2f ms", milliseconds)
        } else if milliseconds < Config.millisecondsThreshold {
            String(format: "%.0f ms", milliseconds)
        } else {
            String(format: "%.1f s", milliseconds / Config.millisecondsThreshold)
        }
    }

    private func abbreviatedLabel(from uuid: String) -> String {
        "Metric \(uuid.prefix(Config.prefixLength))"
    }

    private func sortedData(
        _ data: [ProcessingData],
        by order: ProcessingSortOrder
    ) -> [ProcessingData] {
        switch order {
        case .byTotal:
            data.sorted { $0.total > $1.total }

        case .byInference:
            data.sorted { first, second in
                inferenceValue(first) > inferenceValue(second)
            }

        case .byTokenization:
            data.sorted { first, second in
                tokenizationValue(first) > tokenizationValue(second)
            }

        case .byPostProcessing:
            data.sorted { first, second in
                postProcessingValue(first) > postProcessingValue(second)
            }
        }
    }

    private func inferenceValue(_ data: ProcessingData) -> Double {
        data.components.first { component in
            component.type == .inference
        }?.value ?? 0
    }

    private func tokenizationValue(_ data: ProcessingData) -> Double {
        data.components.first { component in
            component.type == .tokenization
        }?.value ?? 0
    }

    private func postProcessingValue(_ data: ProcessingData) -> Double {
        data.components.first { component in
            component.type == .postProcessing
        }?.value ?? 0
    }
}
