import Foundation

/// Extension to handle mock data creation for HealthKitManager
extension HealthKitManager {
    // MARK: - Mock Data for Testing

    func createMockStepsData(from _: Date, to endDate: Date) -> [HealthDataPoint] {
        let baseSteps: Double = 5_000
        let variation: Double = 2_000

        return [
            HealthDataPoint(
                date: endDate,
                value: baseSteps + Double.random(in: -variation...variation),
                unit: "steps"
            )
        ]
    }

    func createMockHeartRateData(from startDate: Date, to endDate: Date) -> [HealthDataPoint] {
        let baseRate: Double = 70
        let variation: Double = 20

        var dataPoints: [HealthDataPoint] = []
        var currentDate: Date = startDate

        while currentDate <= endDate {
            dataPoints.append(HealthDataPoint(
                date: currentDate,
                value: baseRate + Double.random(in: -variation...variation),
                unit: "bpm"
            ))
            let hourInSeconds: TimeInterval = 3_600
            currentDate = currentDate.addingTimeInterval(hourInSeconds)
        }

        return dataPoints
    }

    func createMockCaloriesData(from _: Date, to endDate: Date) -> [HealthDataPoint] {
        let baseCalories: Double = 500
        let variation: Double = 200

        return [
            HealthDataPoint(
                date: endDate,
                value: baseCalories + Double.random(in: -variation...variation),
                unit: "kcal"
            )
        ]
    }

    func createMockDistanceData(from _: Date, to endDate: Date) -> [HealthDataPoint] {
        let baseDistance: Double = 3.5
        let variation: Double = 1.5

        return [
            HealthDataPoint(
                date: endDate,
                value: baseDistance + Double.random(in: -variation...variation),
                unit: "miles"
            )
        ]
    }
}
