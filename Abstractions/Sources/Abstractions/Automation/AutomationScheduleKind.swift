import Foundation

/// Scheduling strategy for automation.
public enum AutomationScheduleKind: String, Codable, Sendable, CaseIterable {
    case cron
    case oneShot
}
