import Database
import Foundation

// MARK: - Constants

private enum SamplingConstants {
    static let defaultTargetCount: Int = 500
    static let defaultMaxPoints: Int = 1_000
    static let timeIntervalDefault: TimeInterval = 300 // 5 minutes
    static let smallDatasetLimit: Int = 100
    static let mediumDatasetLimit: Int = 500
    static let largeDatasetLimit: Int = 2_000
    static let mediumSamplePoints: Int = 200
    static let largeSamplePoints: Int = 300
    static let minPointsForSampling: Int = 2
    static let bucketCalculationOffset: Int = 2
    static let firstPointIndex: Int = 0
    static let bucketStartOffset: Int = 1
    static let negativeOne: Double = -1
    static let nextBucketOffset: Int = 2
}

// MARK: - Data Sampling for Performance

/// Utilities for sampling large datasets to improve chart rendering performance
public enum DataSampling {
    // MARK: - Helper Types

    private struct BucketBounds {
        let start: Int
        let end: Int
        let nextEnd: Int
    }

    private struct AveragePoint {
        let xCoordinate: Double
        let yCoordinate: Double
    }

    // MARK: - LTTB Algorithm

    /// Largest Triangle Three Buckets (LTTB) algorithm for downsampling time series data
    /// This preserves the visual characteristics of the data while reducing point count
    static func downsampleMetrics(
        _ metrics: [Metrics],
        targetCount: Int = SamplingConstants.defaultTargetCount
    ) -> [Metrics] {
        guard metrics.count > targetCount else {
            return metrics
        }

        let sorted: [Metrics] = metrics.sorted { $0.createdAt < $1.createdAt }
        guard sorted.count > SamplingConstants.minPointsForSampling else {
            return sorted
        }

        var sampled: [Metrics] = [sorted[SamplingConstants.firstPointIndex]]
        let bucketSize: Double = calculateBucketSize(
            dataCount: sorted.count,
            targetCount: targetCount
        )

        var previousPointIndex: Int = 0
        let targetBuckets: Int = targetCount - SamplingConstants.bucketCalculationOffset

        for bucket in 0 ..< targetBuckets {
            let bounds: BucketBounds = calculateBucketBounds(
                bucket: bucket,
                bucketSize: bucketSize,
                dataCount: sorted.count
            )

            let avgPoint: AveragePoint = calculateAveragePoint(
                sorted: sorted,
                startIndex: bounds.end,
                endIndex: bounds.nextEnd
            )

            let maxAreaIndex: Int = findMaxAreaPoint(
                sorted: sorted,
                bounds: bounds,
                previousIndex: previousPointIndex,
                avgPoint: avgPoint
            )

            sampled.append(sorted[maxAreaIndex])
            previousPointIndex = maxAreaIndex
        }

        sampled.append(sorted[sorted.count - 1])
        return sampled
    }

    private static func calculateBucketSize(dataCount: Int, targetCount: Int) -> Double {
        let dataPointsForBuckets: Int = dataCount - SamplingConstants.bucketCalculationOffset
        let targetBuckets: Int = targetCount - SamplingConstants.bucketCalculationOffset
        return Double(dataPointsForBuckets) / Double(targetBuckets)
    }

    private static func calculateBucketBounds(
        bucket: Int,
        bucketSize: Double,
        dataCount: Int
    ) -> BucketBounds {
        let start: Int = Int(Double(bucket) * bucketSize) +
            SamplingConstants.bucketStartOffset
        let end: Int = Int(Double(bucket + 1) * bucketSize) +
            SamplingConstants.bucketStartOffset
        let nextEnd: Int = min(
            Int(Double(bucket + SamplingConstants.nextBucketOffset) * bucketSize) +
                SamplingConstants.bucketStartOffset,
            dataCount - 1
        )
        return BucketBounds(start: start, end: end, nextEnd: nextEnd)
    }

    private static func calculateAveragePoint(
        sorted: [Metrics],
        startIndex: Int,
        endIndex: Int
    ) -> AveragePoint {
        var avgX: Double = 0
        var avgY: Double = 0
        var count: Int = 0

        for index in startIndex ..< endIndex {
            avgX += sorted[index].createdAt.timeIntervalSince1970
            avgY += sorted[index].tokensPerSecond
            count += 1
        }

        if count > 0 {
            avgX /= Double(count)
            avgY /= Double(count)
        }

        return AveragePoint(xCoordinate: avgX, yCoordinate: avgY)
    }

    private static func findMaxAreaPoint(
        sorted: [Metrics],
        bounds: BucketBounds,
        previousIndex: Int,
        avgPoint: AveragePoint
    ) -> Int {
        var maxArea: Double = SamplingConstants.negativeOne
        var maxAreaIndex: Int = bounds.start

        let pointA: Metrics = sorted[previousIndex]
        let pointAX: Double = pointA.createdAt.timeIntervalSince1970
        _ = pointA.tokensPerSecond // Not used in current calculation

        for index in bounds.start ..< bounds.end {
            let point: Metrics = sorted[index]
            let pointX: Double = point.createdAt.timeIntervalSince1970
            let pointY: Double = point.tokensPerSecond

            let area: Double = abs(
                (pointAX - avgPoint.xCoordinate) * (pointY - avgPoint.yCoordinate) -
                    (pointAX - pointX) * (avgPoint.yCoordinate - avgPoint.yCoordinate)
            )

            if area > maxArea {
                maxArea = area
                maxAreaIndex = index
            }
        }

        return maxAreaIndex
    }

    // MARK: - Simple Sampling

    /// Simple nth-point sampling for less critical visualizations
    static func simpleSample(
        _ metrics: [Metrics],
        maxPoints: Int = SamplingConstants.defaultMaxPoints
    ) -> [Metrics] {
        guard metrics.count > maxPoints else {
            return metrics
        }

        let step: Int = metrics.count / maxPoints
        var sampled: [Metrics] = []

        for index in stride(from: 0, to: metrics.count, by: step) {
            sampled.append(metrics[index])
        }

        // Always include the last point
        if let last = metrics.last, sampled.last != last {
            sampled.append(last)
        }

        return sampled
    }

    // MARK: - Time-based Sampling

    /// Sample metrics based on time intervals
    static func timeBasedSample(
        _ metrics: [Metrics],
        interval: TimeInterval = SamplingConstants.timeIntervalDefault
    ) -> [Metrics] {
        guard !metrics.isEmpty else {
            return []
        }

        let sorted: [Metrics] = metrics.sorted { $0.createdAt < $1.createdAt }
        var sampled: [Metrics] = []
        var lastSampleTime: Date = Date.distantPast

        for metric in sorted where metric.createdAt.timeIntervalSince(lastSampleTime) >= interval {
            sampled.append(metric)
            lastSampleTime = metric.createdAt
        }

        // Always include the last metric
        if let last = sorted.last, sampled.last != last {
            sampled.append(last)
        }

        return sampled
    }

    // MARK: - Adaptive Sampling

    /// Automatically choose sampling strategy based on data size
    static func adaptiveSample(_ metrics: [Metrics]) -> [Metrics] {
        switch metrics.count {
        case 0 ..< SamplingConstants.smallDatasetLimit:
            // Small dataset - no sampling needed
            metrics

        case SamplingConstants.smallDatasetLimit ..< SamplingConstants.mediumDatasetLimit:
            // Medium dataset - light sampling
            simpleSample(metrics, maxPoints: SamplingConstants.mediumSamplePoints)

        case SamplingConstants.mediumDatasetLimit ..< SamplingConstants.largeDatasetLimit:
            // Large dataset - moderate sampling with LTTB
            downsampleMetrics(metrics, targetCount: SamplingConstants.largeSamplePoints)

        default:
            // Very large dataset - aggressive sampling
            downsampleMetrics(metrics, targetCount: SamplingConstants.defaultTargetCount)
        }
    }
}

// MARK: - Performance Settings Constants

private enum PerformanceConstants {
    static let maxDataPoints: Int = 500
    static let animationDuration: Double = 0.3
    static let phoneDefaultSize: Int = 200
    static let iPadDefaultSize: Int = 400
    static let macDefaultSize: Int = 500
    static let visionDefaultSize: Int = 400
    static let otherDefaultSize: Int = 300
}
