import Foundation
import os
#if canImport(HealthKit)
import HealthKit
#endif

/// Manager for HealthKit data access
internal final class HealthKitManager: Sendable {
    private static let logger: Logger = Logger(subsystem: "Tools", category: "HealthKitManager")
    /// Health data point representation
    internal struct HealthDataPoint: Sendable {
        internal let date: Date
        internal let value: Double
        internal let unit: String
    }

    /// HealthKit errors
    internal enum HealthKitError: Error, LocalizedError, Sendable {
        case notAvailable
        case notAuthorized
        case queryFailed(String)
        case noData

        internal var errorDescription: String? {
            switch self {
            case .notAvailable:
                return "HealthKit is not available on this device"

            case .notAuthorized:
                return "HealthKit access not authorized"

            case .queryFailed(let message):
                return "HealthKit query failed: \(message)"

            case .noData:
                return "No health data available for the requested period"
            }
        }
    }

    #if canImport(HealthKit)
    internal let healthStore: HKHealthStore = HKHealthStore()
    #endif

    internal init() {
        Self.logger.debug("Initializing HealthKitManager")
        Self.logger.info("HealthKit availability: \(self.isHealthKitAvailable(), privacy: .public)")
    }

    deinit {
        // Clean up resources if needed
    }

    /// Check if HealthKit is available
    internal func isHealthKitAvailable() -> Bool {
        #if canImport(HealthKit)
        return HKHealthStore.isHealthDataAvailable()
        #else
        return false
        #endif
    }

    /// Check authorization status
    internal func isAuthorized() -> Bool {
        #if canImport(HealthKit)
        guard isHealthKitAvailable() else {
            return false
        }

        let stepType: HKQuantityType? = HKQuantityType.quantityType(
            forIdentifier: .stepCount
        )
        guard let stepType else {
            return false
        }

        let status: HKAuthorizationStatus = healthStore.authorizationStatus(for: stepType)
        return status == .sharingAuthorized
        #else
        return false
        #endif
    }

    /// Request authorization for health data
    internal func requestAuthorization() async throws {
        Self.logger.info("Requesting HealthKit authorization")
        #if canImport(HealthKit)
        guard isHealthKitAvailable() else {
            Self.logger.error("HealthKit not available on this device")
            throw HealthKitError.notAvailable
        }

        guard let stepType = HKQuantityType.quantityType(forIdentifier: .stepCount),
            let heartRateType = HKQuantityType.quantityType(forIdentifier: .heartRate),
            let energyType = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned),
            let distanceType = HKQuantityType.quantityType(forIdentifier: .distanceWalkingRunning),
            let sleepType = HKCategoryType.categoryType(forIdentifier: .sleepAnalysis) else {
            throw HealthKitError.notAvailable
        }

        let readTypes: Set<HKSampleType> = [
            stepType,
            heartRateType,
            energyType,
            distanceType,
            sleepType,
            HKWorkoutType.workoutType()
        ]

        try await healthStore.requestAuthorization(toShare: [], read: readTypes)
        Self.logger.notice("HealthKit authorization request completed")
        #else
        Self.logger.error("HealthKit not available - cannot request authorization")
        throw HealthKitError.notAvailable
        #endif
    }

    /// Fetch steps data
    internal func fetchSteps(from startDate: Date, to endDate: Date) async throws -> [HealthDataPoint] {
        #if canImport(HealthKit)
        guard isHealthKitAvailable() else {
            return createMockStepsData(from: startDate, to: endDate)
        }

        guard let stepType = HKQuantityType.quantityType(forIdentifier: .stepCount) else {
            throw HealthKitError.notAvailable
        }
        let predicate: NSPredicate = HKQuery.predicateForSamples(
            withStart: startDate,
            end: endDate,
            options: .strictStartDate
        )

        return try await withCheckedThrowingContinuation { continuation in
            let query: HKStatisticsQuery = HKStatisticsQuery(
                quantityType: stepType,
                quantitySamplePredicate: predicate,
                options: .cumulativeSum
            ) { _, result, error in
                if let error {
                    continuation.resume(throwing: HealthKitError.queryFailed(error.localizedDescription))
                    return
                }

                guard let result,
                    let sum = result.sumQuantity() else {
                    continuation.resume(returning: [])
                    return
                }

                let value: Double = sum.doubleValue(for: HKUnit.count())
                let dataPoint: HealthDataPoint = HealthDataPoint(
                    date: result.endDate,
                    value: value,
                    unit: "steps"
                )
                continuation.resume(returning: [dataPoint])
            }

            healthStore.execute(query)
        }
        #else
        return createMockStepsData(from: startDate, to: endDate)
        #endif
    }

    /// Format date range for display
    internal func formatDateRange(from startDate: Date, to endDate: Date) -> String {
        let formatter: DateFormatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none

        let start: String = formatter.string(from: startDate)
        let end: String = formatter.string(from: endDate)

        return "\(start) to \(end)"
    }
}
