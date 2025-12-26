import SwiftUI

extension SettingsView {
    // MARK: - Tab Labels

    var actionsTabLabel: some View {
        Label(
            String(
                localized: "Actions",
                bundle: .module,
                comment: "Tab label for Actions"
            ),
            systemImage: "hand.tap"
        )
        .accessibility(label: Text("Actions tab"))
    }

    var modelsTabLabel: some View {
        Label(
            String(
                localized: "Models",
                bundle: .module,
                comment: "Tab label for Models"
            ),
            systemImage: "cloud"
        )
        .accessibility(label: Text("Models tab"))
    }

    var legalTabLabel: some View {
        Label(
            String(
                localized: "Legal",
                bundle: .module,
                comment: "Tab label for Legal"
            ),
            systemImage: "doc.text"
        )
        .accessibility(label: Text("Legal tab"))
    }

    var aboutTabLabel: some View {
        Label(
            String(
                localized: "About",
                bundle: .module,
                comment: "Tab label for About"
            ),
            systemImage: "info.circle"
        )
        .accessibility(label: Text("About tab"))
    }

    var reviewTabLabel: some View {
        Label(
            String(
                localized: "Review",
                bundle: .module,
                comment: "Tab label for Review settings"
            ),
            systemImage: "star"
        )
        .accessibility(label: Text("Review settings tab"))
    }

    // MARK: - Models View

    var modelsView: some View {
        APIKeySettingsView()
    }
}
