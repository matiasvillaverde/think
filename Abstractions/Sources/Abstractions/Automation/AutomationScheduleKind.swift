import Foundation

/// Scheduling strategy for automation.
public enum AutomationScheduleKind: String, Codable, Sendable, CaseIterable {
    case cron = "cron"
    case oneShot = "one_shot"
}
