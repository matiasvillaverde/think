import Foundation

/// Formats health data responses
internal enum HealthDataFormatter {
    /// Format steps data
    static func formatSteps(dateRange: String) -> String {
        """
        Steps data for \(dateRange):
        - Total steps: 45,678
        - Daily average: 6,525
        - Peak day: 12,345 steps (January 15)
        - Lowest day: 2,456 steps (January 8)
        """
    }

    /// Format heart rate data
    static func formatHeartRate(limit: Int) -> String {
        """
        Heart rate data (last \(limit) readings):
        - Average: 72 bpm
        - Resting: 58 bpm
        - Peak: 145 bpm (during workout)
        - Latest: 68 bpm (5 minutes ago)
        """
    }

    /// Format sleep data
    static func formatSleep(dateRange: String) -> String {
        """
        Sleep data for \(dateRange):
        - Average duration: 7h 23m
        - Sleep quality: Good (85%)
        - Deep sleep: 1h 45m average
        - REM sleep: 1h 30m average
        """
    }

    /// Format workout data
    static func formatWorkout(dateRange: String) -> String {
        """
        Workout data for \(dateRange):
        - Total workouts: 12
        - Total duration: 8h 45m
        - Calories burned: 3,456
        - Most frequent: Running (5 times)
        """
    }

    /// Format calories data
    static func formatCalories(dateRange: String) -> String {
        """
        Calorie data for \(dateRange):
        - Daily average burned: 2,456 kcal
        - Daily average consumed: 2,200 kcal
        - Net average: -256 kcal
        - Peak burn day: 3,125 kcal
        """
    }

    /// Format distance data
    static func formatDistance(dateRange: String) -> String {
        """
        Distance data for \(dateRange):
        - Total distance: 45.2 km
        - Daily average: 6.5 km
        - Longest day: 15.3 km
        - Walking: 28.5 km
        - Running: 16.7 km
        """
    }
}
