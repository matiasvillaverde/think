import Database
import SwiftUI

/// Displays personalities organized by activity, with featured personalities at top
public struct PersonalitySections: View {
    // MARK: - Properties

    let featuredPersonalities: [Personality]
    let activePersonalities: [Personality]
    let inactivePersonalities: [Personality]
    let alertManager: AlertManager

    // MARK: - Body

    public var body: some View {
        Group {
            featuredSection
            activeSection
            inactiveSection
        }
    }

    @ViewBuilder private var featuredSection: some View {
        if !featuredPersonalities.isEmpty {
            Section(
                String(
                    localized: "Featured",
                    bundle: .module,
                    comment: "Section header for featured personalities"
                )
            ) {
                PersonalityListSection(
                    personalities: featuredPersonalities,
                    alertManager: alertManager
                )
            }
        }
    }

    @ViewBuilder private var activeSection: some View {
        if !activePersonalities.isEmpty {
            Section(
                String(
                    localized: "Recent",
                    bundle: .module,
                    comment: "Section header for recently active personalities"
                )
            ) {
                PersonalityListSection(
                    personalities: activePersonalities,
                    alertManager: alertManager
                )
            }
        }
    }

    @ViewBuilder private var inactiveSection: some View {
        if !inactivePersonalities.isEmpty {
            Section(
                String(
                    localized: "Others",
                    bundle: .module,
                    comment: "Section header for personalities without conversations"
                )
            ) {
                PersonalityListSection(
                    personalities: inactivePersonalities,
                    alertManager: alertManager
                )
            }
        }
    }
}
