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
        .accessibility(label: Text("Actions tab", bundle: .module))
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
        .accessibility(label: Text("Models tab", bundle: .module))
    }

    var openClawTabLabel: some View {
        Label(
            String(
                localized: "OpenClaw",
                bundle: .module,
                comment: "Tab label for OpenClaw remote instances"
            ),
            systemImage: "bolt.horizontal.circle"
        )
        .accessibility(label: Text("OpenClaw tab", bundle: .module))
    }

    var voiceTabLabel: some View {
        Label(
            String(
                localized: "Voice",
                bundle: .module,
                comment: "Tab label for Voice"
            ),
            systemImage: "waveform"
        )
        .accessibility(label: Text("Voice tab", bundle: .module))
    }

    var automationTabLabel: some View {
        Label(
            String(
                localized: "Automation",
                bundle: .module,
                comment: "Tab label for Automation"
            ),
            systemImage: "clock"
        )
        .accessibility(label: Text("Automation tab", bundle: .module))
    }

    var nodeModeTabLabel: some View {
        Label(
            String(
                localized: "Node Mode",
                bundle: .module,
                comment: "Tab label for Node Mode"
            ),
            systemImage: "server.rack"
        )
        .accessibility(label: Text("Node Mode tab", bundle: .module))
    }

    var pluginsTabLabel: some View {
        Label(
            String(
                localized: "Plugins",
                bundle: .module,
                comment: "Tab label for Plugins"
            ),
            systemImage: "puzzlepiece.extension"
        )
        .accessibility(label: Text("Plugins tab", bundle: .module))
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
        .accessibility(label: Text("Legal tab", bundle: .module))
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
        .accessibility(label: Text("About tab", bundle: .module))
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
        .accessibility(label: Text("Review settings tab", bundle: .module))
    }

    // MARK: - Models View

    var modelsView: some View {
        APIKeySettingsView()
    }

    // MARK: - OpenClaw View

    var openClawView: some View {
        OpenClawSettingsView()
    }

    // MARK: - Plugins View

    var pluginsView: some View {
        PluginApprovalSettingsView()
    }
}
