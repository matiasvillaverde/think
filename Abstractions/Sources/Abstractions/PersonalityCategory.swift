import Foundation

// swiftlint:disable line_length

/// Categories for grouping personalities
public enum PersonalityCategory: String, CaseIterable, Codable, Sendable {
    case creative
    case education
    case entertainment
    case health
    case lifestyle
    case personal
    case productivity

    public var displayName: String {
        switch self {
        case .creative:
            return String(localized: "Creative", bundle: .module)
        case .education:
            return String(localized: "Education", bundle: .module)
        case .entertainment:
            return String(localized: "Entertainment", bundle: .module)
        case .health:
            return String(localized: "Health & Wellness", bundle: .module)
        case .lifestyle:
            return String(localized: "Lifestyle", bundle: .module)
        case .personal:
            return String(localized: "Personal", bundle: .module)
        case .productivity:
            return String(localized: "Productivity", bundle: .module)
        }
    }
}
