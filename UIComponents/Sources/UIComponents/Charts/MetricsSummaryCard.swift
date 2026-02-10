import Database
import SwiftUI

#if canImport(UIKit)
    import UIKit
#endif

public struct MetricsSummaryCard: View {
    let metrics: Metrics?
    @Environment(\.horizontalSizeClass)
    private var horizontalSizeClass: UserInterfaceSizeClass?

    private enum Constants {
        static let spacing: CGFloat = 16
        static let cornerRadius: CGFloat = 12
        static let shadowRadius: CGFloat = 2
        static let iconSize: CGFloat = 24
        static let dividerPadding: CGFloat = 8
        static let percentFormat: String = "%.1f%%"
        static let decimalFormat: String = "%.2f"
        static let intFormat: String = "%.0f"
        static let percentMultiplier: Double = 100
        static let kilobyte: Double = 1_024
        static let megabyte: Double = 1_048_576
        static let millisecondsMultiplier: Double = 1_000
        static let halfDivider: CGFloat = 2
        static let minCardWidth: CGFloat = 200
        static let maxCardWidth: CGFloat = 500
        static let iPhoneSpacingMultiplier: CGFloat = 0.75
        static let iPhonePadding: CGFloat = 12
        static let defaultPadding: CGFloat = 16
    }

    public init(metrics: Metrics?) {
        self.metrics = metrics
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: adaptiveSpacing) {
            headerView

            if let metrics {
                VStack(spacing: adaptiveSpacing) {
                    performanceSection(metrics)
                    Divider().padding(.vertical, Constants.dividerPadding)
                    qualitySection(metrics)
                    Divider().padding(.vertical, Constants.dividerPadding)
                    resourceSection(metrics)
                }
            } else {
                emptyStateView
            }
        }
        .padding(adaptivePadding)
        .frame(minWidth: Constants.minCardWidth, maxWidth: Constants.maxCardWidth)
        .background(.background)
        .clipShape(RoundedRectangle(cornerRadius: Constants.cornerRadius))
        .shadow(radius: Constants.shadowRadius)
    }

    private var adaptiveSpacing: CGFloat {
        #if os(iOS)
            if UIDevice.current.userInterfaceIdiom == .phone {
                return Constants.spacing * Constants.iPhoneSpacingMultiplier
            }
        #endif
        return Constants.spacing
    }

    private var adaptivePadding: CGFloat {
        #if os(iOS)
            if UIDevice.current.userInterfaceIdiom == .phone {
                return Constants.iPhonePadding
            }
        #endif
        return Constants.defaultPadding
    }

    private var headerView: some View {
        HStack {
            Image(systemName: "chart.bar.doc.horizontal")
                .font(.system(size: Constants.iconSize))
                .foregroundStyle(.blue)
                .accessibilityLabel(Text("Chart icon", bundle: .module))
            Text("Metrics Summary", bundle: .module)
                .font(.headline)
                .foregroundStyle(Color.textPrimary)
            Spacer()
        }
    }

    private var emptyStateView: some View {
        ContentUnavailableView(
            String(localized: "No Metrics Data", bundle: .module),
            systemImage: "chart.bar",
            description: Text("Metrics will appear here", bundle: .module)
        )
        .frame(maxWidth: .infinity)
    }

    private func performanceSection(_ metrics: Metrics) -> some View {
        VStack(alignment: .leading, spacing: Constants.spacing / Constants.halfDivider) {
            Label {
                Text("Performance", bundle: .module)
            } icon: {
                Image(systemName: "speedometer")
                    .accessibilityHidden(true)
            }
                .font(.subheadline)
                .fontWeight(.semibold)

            metricRow(
                label: String(localized: "Tokens/Second", bundle: .module),
                value: String(format: Constants.decimalFormat, metrics.tokensPerSecond)
            )
            metricRow(
                label: String(localized: "Time to First Token", bundle: .module),
                value: String(
                    format: Constants.intFormat,
                    (metrics.timeToFirstToken ?? 0) * Constants.millisecondsMultiplier
                ) + " ms"
            )
            metricRow(
                label: String(localized: "Total Generation Time", bundle: .module),
                value: String(
                    format: Constants.intFormat,
                    metrics.totalTime * Constants.millisecondsMultiplier
                ) + " ms"
            )
        }
    }

    private func qualitySection(_: Metrics) -> some View {
        VStack(alignment: .leading, spacing: Constants.spacing / Constants.halfDivider) {
            Label {
                Text("Quality", bundle: .module)
            } icon: {
                Image(systemName: "star")
                    .accessibilityHidden(true)
            }
                .font(.subheadline)
                .fontWeight(.semibold)

            // Quality metrics are not available in current Metrics model
            // Showing placeholder message
            Text("Quality metrics coming soon", bundle: .module)
                .font(.caption)
                .foregroundStyle(Color.textSecondary)
                .italic()
        }
    }

    private func resourceSection(_ metrics: Metrics) -> some View {
        VStack(alignment: .leading, spacing: Constants.spacing / Constants.halfDivider) {
            Label {
                Text("Resources", bundle: .module)
            } icon: {
                Image(systemName: "cpu")
                    .accessibilityHidden(true)
            }
                .font(.subheadline)
                .fontWeight(.semibold)

            metricRow(
                label: String(localized: "Peak Memory", bundle: .module),
                value: formatMemory(Int(metrics.peakMemory))
            )
            if let contextTokensUsed = metrics.contextTokensUsed,
                let contextWindowSize = metrics.contextWindowSize,
                contextWindowSize > 0 {
                let utilization: Double = Double(contextTokensUsed) / Double(contextWindowSize)
                metricRow(
                    label: String(localized: "Context Usage", bundle: .module),
                    value: String(
                        format: Constants.percentFormat,
                        utilization * Constants.percentMultiplier
                    )
                )
            }
            metricRow(
                label: String(localized: "Total Tokens", bundle: .module),
                value: "\(metrics.promptTokens + metrics.generatedTokens)"
            )
        }
    }

    private func metricRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.caption)
                .foregroundStyle(Color.textSecondary)
            Spacer()
            Text(value)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundStyle(Color.textPrimary)
        }
    }

    private func formatMemory(_ bytes: Int) -> String {
        let megabytes: Double = Double(bytes) / Constants.megabyte
        if megabytes >= 1 {
            return String(format: Constants.decimalFormat + " MB", megabytes)
        }
        let kilobytes: Double = Double(bytes) / Constants.kilobyte
        return String(format: Constants.intFormat + " KB", kilobytes)
    }
}

#if DEBUG
    #Preview("Metrics Summary Card - With Data") {
        MetricsSummaryCard(
            metrics: Metrics.preview(
                totalTime: 2.5,
                timeToFirstToken: 0.15,
                promptTokens: 500,
                generatedTokens: 1_500,
                totalTokens: 2_000,
                contextWindowSize: 4_096,
                contextTokensUsed: 2_000,
                peakMemory: 52_428_800
            )
        )
        .frame(width: 300)
        .padding()
    }
#endif

#if DEBUG
    #Preview("Metrics Summary Card - Empty") {
        MetricsSummaryCard(metrics: nil)
            .frame(width: 300)
            .padding()
    }
#endif
