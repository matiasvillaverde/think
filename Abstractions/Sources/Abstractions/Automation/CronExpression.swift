import Foundation

/// Represents a parsed cron expression with minute-level precision.
public struct CronExpression: Sendable, Equatable {
    private let minutes: Set<Int>
    private let hours: Set<Int>
    private let daysOfMonth: Set<Int>
    private let months: Set<Int>
    private let weekdays: Set<Int>

    /// Creates a cron expression from a standard 5-field string.
    /// Format: "minute hour day-of-month month day-of-week"
    public init(_ expression: String) throws {
        let fields: [Substring] = expression
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .split(separator: " ")
        guard fields.count == 5 else {
            throw CronExpressionError.invalidFieldCount
        }

        minutes = try CronExpression.parseField(fields[0], min: 0, max: 59)
        hours = try CronExpression.parseField(fields[1], min: 0, max: 23)
        daysOfMonth = try CronExpression.parseField(fields[2], min: 1, max: 31)
        months = try CronExpression.parseField(fields[3], min: 1, max: 12)
        weekdays = try CronExpression.parseField(fields[4], min: 0, max: 6)
    }

    /// Calculates the next date that matches this cron expression.
    /// - Parameters:
    ///   - date: The starting date (exclusive).
    ///   - calendar: Calendar to use for date computations.
    ///   - maxIterations: Maximum minutes to scan to avoid infinite loops.
    /// - Returns: The next matching date, or nil if none found.
    public func nextDate(
        after date: Date,
        calendar: Calendar = .current,
        maxIterations: Int = 525_600
    ) -> Date? {
        guard maxIterations > 0 else {
            return nil
        }

        let aligned: Date = CronExpression.alignToNextMinute(after: date, calendar: calendar)
        var candidate: Date = aligned

        for _ in 0..<maxIterations {
            let components = calendar.dateComponents(
                [.minute, .hour, .day, .month, .weekday],
                from: candidate
            )

            guard let minute = components.minute,
                  let hour = components.hour,
                  let day = components.day,
                  let month = components.month,
                  let weekday = components.weekday else {
                return nil
            }

            let normalizedWeekday: Int = CronExpression.normalizeWeekday(weekday)

            if minutes.contains(minute),
               hours.contains(hour),
               daysOfMonth.contains(day),
               months.contains(month),
               weekdays.contains(normalizedWeekday) {
                return candidate
            }

            guard let next = calendar.date(byAdding: .minute, value: 1, to: candidate) else {
                return nil
            }
            candidate = next
        }

        return nil
    }

    // MARK: - Parsing

    private static func parseField(
        _ field: Substring,
        min: Int,
        max: Int
    ) throws -> Set<Int> {
        let raw: String = String(field)
        if raw == "*" {
            return Set(min...max)
        }

        var result: Set<Int> = []
        let parts: [Substring] = raw.split(separator: ",")
        for part in parts {
            if part.hasPrefix("*/") {
                let stepValue = part.dropFirst(2)
                guard let step = Int(stepValue), step > 0 else {
                    throw CronExpressionError.invalidStep
                }
                var value: Int = min
                while value <= max {
                    result.insert(value)
                    value += step
                }
                continue
            }

            if part.contains("-") {
                let bounds = part.split(separator: "-")
                guard bounds.count == 2,
                      let start = Int(bounds[0]),
                      let end = Int(bounds[1]),
                      start <= end else {
                    throw CronExpressionError.invalidRange
                }
                guard start >= min, end <= max else {
                    throw CronExpressionError.outOfBounds
                }
                result.formUnion(start...end)
                continue
            }

            guard let value = Int(part) else {
                throw CronExpressionError.invalidValue
            }
            guard value >= min, value <= max else {
                throw CronExpressionError.outOfBounds
            }
            result.insert(value)
        }

        guard !result.isEmpty else {
            throw CronExpressionError.emptyField
        }

        return result
    }

    private static func alignToNextMinute(after date: Date, calendar: Calendar) -> Date {
        let seconds: Int = calendar.component(.second, from: date)
        let nanoseconds: Int = calendar.component(.nanosecond, from: date)
        let totalNanoseconds: Int = seconds * 1_000_000_000 + nanoseconds
        let needsIncrement: Bool = totalNanoseconds > 0

        guard var nextMinute = calendar.date(bySetting: .second, value: 0, of: date) else {
            return date
        }
        nextMinute = calendar.date(bySetting: .nanosecond, value: 0, of: nextMinute) ?? nextMinute

        if needsIncrement, let advanced = calendar.date(byAdding: .minute, value: 1, to: nextMinute) {
            return advanced
        }
        return nextMinute
    }

    private static func normalizeWeekday(_ weekday: Int) -> Int {
        // Calendar weekday: 1 = Sunday, 7 = Saturday
        // Cron weekday: 0 = Sunday, 6 = Saturday
        (weekday - 1 + 7) % 7
    }
}

/// Errors thrown when parsing cron expressions.
public enum CronExpressionError: Error, Sendable {
    case invalidFieldCount
    case invalidStep
    case invalidRange
    case invalidValue
    case outOfBounds
    case emptyField
}
