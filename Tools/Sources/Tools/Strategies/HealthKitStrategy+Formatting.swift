import Foundation

/// Extension to handle HealthKit data formatting
extension HealthKitStrategy {
    /// Format steps data
    func formatStepsData(_ dataPoints: [HealthKitManager.HealthDataPoint], dateRange: String) -> String {
        guard !dataPoints.isEmpty else {
            return "No steps data available for \(dateRange)"
        }

        let totalSteps: Double = dataPoints.reduce(0) { $0 + $1.value }
        let avgSteps: Double = totalSteps / Double(dataPoints.count)

        var result: String = "Steps Data for \(dateRange):\n"
        result += "Total: \(Int(totalSteps)) steps\n"
        result += "Average: \(Int(avgSteps)) steps/day\n\n"

        let maxDisplayItems: Int = 5
        for point in dataPoints.prefix(maxDisplayItems) {
            let dateFormatter: DateFormatter = DateFormatter()
            dateFormatter.dateStyle = .short
            result += "\(dateFormatter.string(from: point.date)): \(Int(point.value)) \(point.unit)\n"
        }

        return result
    }

    /// Format heart rate data
    func formatHeartRateData<S: Sequence>(_ dataPoints: S) -> String
        where S.Element == HealthKitManager.HealthDataPoint {
        let points: [HealthKitManager.HealthDataPoint] = Array(dataPoints)
        guard !points.isEmpty else {
            return "No heart rate data available"
        }

        let avgRate: Double = points.reduce(0) { $0 + $1.value } / Double(points.count)
        let minRate: Double = points.map(\.value).min() ?? 0
        let maxRate: Double = points.map(\.value).max() ?? 0

        var result: String = "Heart Rate Data:\n"
        result += "Average: \(Int(avgRate)) bpm\n"
        result += "Min: \(Int(minRate)) bpm\n"
        result += "Max: \(Int(maxRate)) bpm\n\n"
        result += "Recent readings:\n"

        for point in points.prefix(ToolConstants.maxDisplayHealthItems) {
            let dateFormatter: DateFormatter = DateFormatter()
            dateFormatter.timeStyle = .short
            result += "\(dateFormatter.string(from: point.date)): \(Int(point.value)) \(point.unit)\n"
        }

        return result
    }

    /// Format calories data
    func formatCaloriesData(_ dataPoints: [HealthKitManager.HealthDataPoint], dateRange: String) -> String {
        guard !dataPoints.isEmpty else {
            return "No calories data available for \(dateRange)"
        }

        let totalCalories: Double = dataPoints.reduce(0) { $0 + $1.value }
        let avgCalories: Double = totalCalories / Double(dataPoints.count)

        var result: String = "Calories Data for \(dateRange):\n"
        result += "Total: \(Int(totalCalories)) kcal\n"
        result += "Average: \(Int(avgCalories)) kcal/day\n\n"

        let maxDisplayItems: Int = 5
        for point in dataPoints.prefix(maxDisplayItems) {
            let dateFormatter: DateFormatter = DateFormatter()
            dateFormatter.dateStyle = .short
            result += "\(dateFormatter.string(from: point.date)): \(Int(point.value)) \(point.unit)\n"
        }

        return result
    }

    /// Format distance data
    func formatDistanceData(_ dataPoints: [HealthKitManager.HealthDataPoint], dateRange: String) -> String {
        guard !dataPoints.isEmpty else {
            return "No distance data available for \(dateRange)"
        }

        let totalDistance: Double = dataPoints.reduce(0) { $0 + $1.value }
        let avgDistance: Double = totalDistance / Double(dataPoints.count)

        var result: String = "Distance Data for \(dateRange):\n"
        result += "Total: \(String(format: "%.2f", totalDistance)) miles\n"
        result += "Average: \(String(format: "%.2f", avgDistance)) miles/day\n\n"

        let maxDisplayItems: Int = 5
        for point in dataPoints.prefix(maxDisplayItems) {
            let dateFormatter: DateFormatter = DateFormatter()
            dateFormatter.dateStyle = .short
            let formattedValue: String = String(format: "%.2f", point.value)
            result += "\(dateFormatter.string(from: point.date)): \(formattedValue) \(point.unit)\n"
        }

        return result
    }

    /// Format date range for display
    /// - Parameters:
    ///   - startDate: Optional start date
    ///   - endDate: Optional end date
    /// - Returns: Formatted date range string
    func formatDateRange(startDate: String?, endDate: String?) -> String {
        if let start = startDate, let end = endDate {
            return "\(start) to \(end)"
        }
        if let start = startDate {
            return "from \(start)"
        }
        if let end = endDate {
            return "until \(end)"
        }
        return "last 7 days"
    }

    /// Generate mock health data for testing
    func generateMockHealthData(
        dataType: String,
        startDate _: Date,
        endDate _: Date,
        limit: Int
    ) -> String {
        // For mock data, always show "last 7 days" when dates are not provided explicitly
        let dateRange: String = "last 7 days"

        switch dataType {
        case "steps":
            return HealthDataFormatter.formatSteps(dateRange: dateRange)

        case "heartRate":
            return HealthDataFormatter.formatHeartRate(limit: limit)

        case "sleep":
            return HealthDataFormatter.formatSleep(dateRange: dateRange)

        case "workout":
            return HealthDataFormatter.formatWorkout(dateRange: dateRange)

        case "calories":
            return HealthDataFormatter.formatCalories(dateRange: dateRange)

        case "distance":
            return HealthDataFormatter.formatDistance(dateRange: dateRange)

        default:
            return "No data available for type: \(dataType)"
        }
    }
}
