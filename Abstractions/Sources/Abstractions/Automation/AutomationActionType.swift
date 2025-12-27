import Foundation

/// Action type for automated schedules.
public enum AutomationActionType: String, Codable, Sendable, CaseIterable {
    case text
    case image
}
