import SwiftUI

// MARK: - Analytics Views Extension

extension SettingsView {
    // MARK: - Analytics View

    /// Main view for the analytics section
    var analyticsView: some View {
        VStack(spacing: Constants.sectionSpacing) {
            analyticsHeader
            DashboardContainer(
                context: DashboardContext(),
                initialType: .appWide
            )
            .padding(.horizontal, Constants.contentPadding)
            Spacer()
        }
    }

    /// Header view for the analytics section
    var analyticsHeader: some View {
        Text(String(
            localized: "Analytics",
            bundle: .module,
            comment: "Analytics section title"
        ))
        .font(.title2)
        .fontWeight(.bold)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, Constants.contentPadding)
        .padding(.top, Constants.contentPadding)
    }

    /// Tab label for the analytics section
    var analyticsTabLabel: some View {
        Label(
            String(
                localized: "Analytics",
                bundle: .module,
                comment: "Tab label for Analytics"
            ),
            systemImage: "chart.line.uptrend.xyaxis"
        )
        .accessibility(label: Text("Analytics tab"))
    }
}
