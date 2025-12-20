import Foundation

/// Protocol for formatters that need date formatting
internal protocol DateFormatting {
    func formatDate(_ date: Date) -> String
}

/// Default implementation for date formatting
extension DateFormatting {
    func formatDate(_ date: Date) -> String {
        let formatter: DateFormatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = TimeZone(identifier: "UTC")
        return formatter.string(from: date)
    }
}
