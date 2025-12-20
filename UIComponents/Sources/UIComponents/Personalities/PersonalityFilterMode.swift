// Personality.swift
import Abstractions
import Database
import Foundation
import SwiftUI

/// Filter options for personality list
internal enum PersonalityFilterMode: CaseIterable {
    case all
    case creative
    case productivity

    var displayName: String {
        switch self {
        case .all:
            String(localized: "All", bundle: .module)

        case .productivity:
            String(localized: "Productivity", bundle: .module)

        case .creative:
            String(localized: "Creative", bundle: .module)
        }
    }
}
