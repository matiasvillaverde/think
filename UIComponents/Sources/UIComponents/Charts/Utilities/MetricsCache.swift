import Database
import Foundation

// MARK: - Metrics Cache

/// Caching layer to store processed metrics and avoid redundant calculations
@preconcurrency
@MainActor
public final class MetricsCache: ObservableObject {
    // MARK: - Cache Storage

    private var filteredMetricsCache: [String: [Metrics]] = [:]
    private var statisticsCache: [String: MetricsStatistics] = [:]
    private var lastUpdateTime: Date?
    private static let cacheValidityDurationSeconds: TimeInterval = 60
    private let cacheValidityDuration: TimeInterval = MetricsCache.cacheValidityDurationSeconds

    // MARK: - Published Properties

    @Published var isCacheValid: Bool = false

    // MARK: - Cache Keys

    private func cacheKey(for timeRange: AppWideDashboard.TimeRange) -> String {
        "metrics_\(timeRange.rawValue)"
    }

    private func statisticsKey(for timeRange: AppWideDashboard.TimeRange) -> String {
        "stats_\(timeRange.rawValue)"
    }

    // MARK: - Cache Management

    /// Check if cache is still valid
    func checkCacheValidity() {
        guard let lastUpdate = lastUpdateTime else {
            isCacheValid = false
            return
        }

        isCacheValid = Date().timeIntervalSince(lastUpdate) < cacheValidityDuration
    }

    // Get cached filtered metrics
    func getCachedMetrics(for timeRange: AppWideDashboard.TimeRange) -> [Metrics] {
        checkCacheValidity()
        guard isCacheValid else {
            return []
        }
        return filteredMetricsCache[cacheKey(for: timeRange)] ?? []
    }

    /// Store filtered metrics in cache
    func cacheMetrics(_ metrics: [Metrics], for timeRange: AppWideDashboard.TimeRange) {
        filteredMetricsCache[cacheKey(for: timeRange)] = metrics
        lastUpdateTime = Date()
        isCacheValid = true
    }

    // Get cached statistics
    func getCachedStatistics(for timeRange: AppWideDashboard.TimeRange) -> MetricsStatistics? {
        checkCacheValidity()
        guard isCacheValid else {
            return nil
        }
        return statisticsCache[statisticsKey(for: timeRange)]
    }

    /// Store statistics in cache
    func cacheStatistics(_ stats: MetricsStatistics, for timeRange: AppWideDashboard.TimeRange) {
        statisticsCache[statisticsKey(for: timeRange)] = stats
        lastUpdateTime = Date()
        isCacheValid = true
    }

    /// Clear all caches
    func clearCache() {
        filteredMetricsCache.removeAll()
        statisticsCache.removeAll()
        lastUpdateTime = nil
        isCacheValid = false
    }

    /// Clear cache for specific time range
    func clearCache(for timeRange: AppWideDashboard.TimeRange) {
        filteredMetricsCache.removeValue(forKey: cacheKey(for: timeRange))
        statisticsCache.removeValue(forKey: statisticsKey(for: timeRange))
    }

    /// Invalidate cache (mark as stale without clearing)
    func invalidateCache() {
        isCacheValid = false
    }

    // MARK: - Singleton Instance

    /// Shared instance of the metrics cache
    public static let shared: MetricsCache = .init()

    deinit {
        // Required by SwiftLint
    }
}
