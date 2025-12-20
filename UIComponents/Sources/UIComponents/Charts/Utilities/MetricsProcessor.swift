import Database
import Foundation

// MARK: - Constants

private enum ProcessorConstants {
    static let dayInSeconds: TimeInterval = 86_400
    static let weekInSeconds: TimeInterval = 604_800
    static let monthInSeconds: TimeInterval = 2_592_000
    static let chunkSizeMinimum: Int = 100
    static let chunkDivisor: Int = 10
    static let capacityDivisor: Int = 2
    static let progressCompleted: Double = 1.0
    static let progressInitial: Double = 0.0
}

// MARK: - Metrics Processor

/// Handles background processing of metrics data to avoid blocking the main thread
@preconcurrency
@MainActor
public final class MetricsProcessor: ObservableObject {
    // MARK: - Published Properties

    @Published public var loadingState: LoadingState<[Metrics]> = .idle
    @Published public var cachedStatistics: MetricsStatistics = .init()
    @Published var isProcessing: Bool = false
    @Published var processingProgress: Double = 0.0
    @Published var lastProcessedDate: Date?

    // MARK: - Private Properties

    private let cache: MetricsCache = .init()

    // MARK: - Processing Methods

    /// Process metrics filtering
    func filterMetrics(
        _ metrics: [Metrics],
        timeRange: AppWideDashboard.TimeRange,
        progressHandler: ((Double) -> Void)? = nil
    ) async -> [Metrics] {
        isProcessing = true
        processingProgress = ProcessorConstants.progressInitial
        defer {
            isProcessing = false
            processingProgress = ProcessorConstants.progressCompleted
            lastProcessedDate = Date()
        }

        let now: Date = Date()
        let cutoffDate: Date

        switch timeRange {
        case .day:
            cutoffDate = now.addingTimeInterval(-ProcessorConstants.dayInSeconds)

        case .week:
            cutoffDate = now.addingTimeInterval(-ProcessorConstants.weekInSeconds)

        case .month:
            cutoffDate = now.addingTimeInterval(-ProcessorConstants.monthInSeconds)

        case .all:
            return metrics
        }

        // Process in chunks to report progress
        let chunkSize: Int = max(
            ProcessorConstants.chunkSizeMinimum,
            metrics.count / ProcessorConstants.chunkDivisor
        )
        var filtered: [Metrics] = []
        filtered.reserveCapacity(metrics.count / ProcessorConstants.capacityDivisor)

        for (index, metric) in metrics.enumerated() {
            if metric.createdAt >= cutoffDate {
                filtered.append(metric)
            }

            // Report progress every chunk
            if index.isMultiple(of: chunkSize) {
                let progress: Double = Double(index) / Double(metrics.count)
                processingProgress = progress
                progressHandler?(progress)

                // Allow UI to update
                await Task.yield()
            }
        }

        return filtered
    }

    /// Calculate statistics
    func calculateStatistics(
        for metrics: [Metrics]
    ) -> MetricsStatistics {
        isProcessing = true
        defer { isProcessing = false }

        var stats: MetricsStatistics = MetricsStatistics()

        guard !metrics.isEmpty else {
            return stats
        }

        // Calculate totals
        var totalTokens: Int = 0
        var totalTime: Double = 0
        var totalPromptTokens: Int = 0
        var totalGeneratedTokens: Int = 0
        var modelCounts: [String: Int] = [:]

        for metric in metrics {
            totalTokens += metric.promptTokens + metric.generatedTokens
            totalPromptTokens += metric.promptTokens
            totalGeneratedTokens += metric.generatedTokens
            totalTime += metric.totalTime

            if let model = metric.modelName {
                modelCounts[model, default: 0] += 1
            }
        }

        // Calculate averages
        let count: Double = Double(metrics.count)
        stats.totalMetrics = metrics.count
        stats.totalTokens = totalTokens
        stats.totalPromptTokens = totalPromptTokens
        stats.totalGeneratedTokens = totalGeneratedTokens
        stats.averageResponseTime = totalTime / count
        stats.averageTokensPerSecond = metrics.map(\.tokensPerSecond).reduce(0, +) / count
        stats.uniqueModelsCount = modelCounts.count
        stats.modelUsageCounts = modelCounts

        // Find peak values
        stats.peakTokensPerSecond = metrics.map(\.tokensPerSecond).max() ?? 0
        stats.peakResponseTime = metrics.map(\.totalTime).max() ?? 0

        return stats
    }

    /// Process messages with metrics
    func filterMessagesWithMetrics(
        _ messages: [Message]
    ) -> [Message] {
        messages.filter { $0.metrics != nil }
    }

    /// Group metrics by time intervals for charts
    func groupMetricsByInterval(
        _ metrics: [Metrics],
        interval: TimeInterval
    ) -> [(date: Date, metrics: [Metrics])] {
        guard !metrics.isEmpty else {
            return []
        }

        let sorted: [Metrics] = metrics.sorted { $0.createdAt < $1.createdAt }
        var grouped: [(date: Date, metrics: [Metrics])] = []
        var currentGroup: [Metrics] = []
        var currentInterval: Date?

        for metric in sorted {
            let intervalDate: Date = Date(
                timeIntervalSince1970: floor(
                    metric.createdAt.timeIntervalSince1970 / interval
                ) * interval
            )

            if currentInterval == nil {
                currentInterval = intervalDate
            }

            if intervalDate == currentInterval {
                currentGroup.append(metric)
            } else {
                if !currentGroup.isEmpty, let interval = currentInterval {
                    grouped.append((date: interval, metrics: currentGroup))
                }
                currentGroup = [metric]
                currentInterval = intervalDate
            }
        }

        // Add last group
        if !currentGroup.isEmpty, let interval = currentInterval {
            grouped.append((date: interval, metrics: currentGroup))
        }

        return grouped
    }

    /// Load metrics for a given time range
    func loadMetrics(
        allMetrics: [Metrics],
        timeRange: AppWideDashboard.TimeRange
    ) async {
        // Check cache first
        let cachedMetrics: [Metrics] = cache.getCachedMetrics(for: timeRange)
        if !cachedMetrics.isEmpty,
            let cachedStats = cache.getCachedStatistics(for: timeRange) {
            loadingState = .loaded(cachedMetrics)
            cachedStatistics = cachedStats
            return
        }

        // Start loading
        loadingState = .loading(progress: 0)

        // Filter metrics in background
        let filtered: [Metrics] = await filterMetrics(
            allMetrics,
            timeRange: timeRange
        ) { progress in
            self.loadingState = .loading(progress: progress)
        }

        // Calculate statistics in background
        let stats: MetricsStatistics = calculateStatistics(for: filtered)

        // Cache results
        cache.cacheMetrics(filtered, for: timeRange)
        cache.cacheStatistics(stats, for: timeRange)

        // Update UI
        cachedStatistics = stats
        loadingState = .loaded(filtered)
    }

    deinit {
        // Required by SwiftLint
    }
}

// MARK: - Supporting Types

/// Aggregated statistics for metrics
public struct MetricsStatistics: Sendable {
    var totalMetrics: Int = 0
    var totalTokens: Int = 0
    var totalPromptTokens: Int = 0
    var totalGeneratedTokens: Int = 0
    var averageResponseTime: Double = 0
    var averageTokensPerSecond: Double = 0
    var peakTokensPerSecond: Double = 0
    var peakResponseTime: Double = 0
    var uniqueModelsCount: Int = 0
    var modelUsageCounts: [String: Int] = [:]

    private static let million: Double = 1_000_000
    private static let thousand: Double = 1_000

    /// Format large numbers for display
    func formatNumber(_ number: Int) -> String {
        if number >= Int(Self.million) {
            return String(format: "%.1fM", Double(number) / Self.million)
        }
        if number >= Int(Self.thousand) {
            return String(format: "%.1fK", Double(number) / Self.thousand)
        }
        return "\(number)"
    }
}
