import Foundation
#if canImport(HealthKit)
import HealthKit
#endif

/// Extension to handle HealthKit query operations
extension HealthKitManager {
    /// Fetch heart rate data
    internal func fetchHeartRate(from startDate: Date, to endDate: Date) async throws -> [HealthDataPoint] {
        #if canImport(HealthKit)
        guard isHealthKitAvailable() else {
            return createMockHeartRateData(from: startDate, to: endDate)
        }

        guard let heartRateType = HKQuantityType.quantityType(forIdentifier: .heartRate) else {
            throw HealthKitError.notAvailable
        }

        let predicate: NSPredicate = HKQuery.predicateForSamples(
            withStart: startDate,
            end: endDate,
            options: .strictStartDate
        )

        return try await withCheckedThrowingContinuation { continuation in
            let query: HKSampleQuery = HKSampleQuery(
                sampleType: heartRateType,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)]
            ) { _, samples, error in
                if let error {
                    continuation.resume(throwing: HealthKitError.queryFailed(error.localizedDescription))
                    return
                }

                guard let samples = samples as? [HKQuantitySample] else {
                    continuation.resume(returning: [])
                    return
                }

                let dataPoints: [HealthDataPoint] = samples.map { sample in
                    let value: Double = sample.quantity.doubleValue(for: HKUnit(from: "count/min"))
                    return HealthDataPoint(date: sample.startDate, value: value, unit: "bpm")
                }

                continuation.resume(returning: dataPoints)
            }

            healthStore.execute(query)
        }
        #else
        return createMockHeartRateData(from: startDate, to: endDate)
        #endif
    }

    /// Fetch calories data
    internal func fetchCalories(from startDate: Date, to endDate: Date) async throws -> [HealthDataPoint] {
        #if canImport(HealthKit)
        guard isHealthKitAvailable() else {
            return createMockCaloriesData(from: startDate, to: endDate)
        }

        guard let caloriesType = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned) else {
            throw HealthKitError.notAvailable
        }

        let predicate: NSPredicate = HKQuery.predicateForSamples(
            withStart: startDate,
            end: endDate,
            options: .strictStartDate
        )

        return try await withCheckedThrowingContinuation { continuation in
            let query: HKStatisticsQuery = HKStatisticsQuery(
                quantityType: caloriesType,
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

                let value: Double = sum.doubleValue(for: HKUnit.kilocalorie())
                let dataPoint: HealthDataPoint = HealthDataPoint(
                    date: result.endDate,
                    value: value,
                    unit: "kcal"
                )
                continuation.resume(returning: [dataPoint])
            }

            healthStore.execute(query)
        }
        #else
        return createMockCaloriesData(from: startDate, to: endDate)
        #endif
    }

    /// Fetch distance data
    internal func fetchDistance(from startDate: Date, to endDate: Date) async throws -> [HealthDataPoint] {
        #if canImport(HealthKit)
        guard isHealthKitAvailable() else {
            return createMockDistanceData(from: startDate, to: endDate)
        }

        guard let distanceType = HKQuantityType.quantityType(forIdentifier: .distanceWalkingRunning) else {
            throw HealthKitError.notAvailable
        }

        let predicate: NSPredicate = HKQuery.predicateForSamples(
            withStart: startDate,
            end: endDate,
            options: .strictStartDate
        )

        return try await withCheckedThrowingContinuation { continuation in
            let query: HKStatisticsQuery = HKStatisticsQuery(
                quantityType: distanceType,
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

                let value: Double = sum.doubleValue(for: HKUnit.mile())
                let dataPoint: HealthDataPoint = HealthDataPoint(
                    date: result.endDate,
                    value: value,
                    unit: "miles"
                )
                continuation.resume(returning: [dataPoint])
            }

            healthStore.execute(query)
        }
        #else
        return createMockDistanceData(from: startDate, to: endDate)
        #endif
    }
}
