import SwiftUI

internal enum PersonalityModelSource: CaseIterable, Identifiable {
    case local
    case remote

    internal var id: String {
        switch self {
        case .local:
            return "local"

        case .remote:
            return "remote"
        }
    }

    internal var title: String {
        switch self {
        case .local:
            return String(localized: "Local", bundle: .module)

        case .remote:
            return String(localized: "Remote", bundle: .module)
        }
    }
}
