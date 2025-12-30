import Abstractions
import SwiftUI

// MARK: - Plugin Approval Settings View

public struct PluginApprovalSettingsView: View {
    @Environment(\.pluginApprovalViewModel)
    private var pluginApprovalViewModel: PluginApprovalViewModeling

    @State private var plugins: [PluginCatalogEntry] = []
    @State private var isLoading: Bool = false
    @State private var errorMessage: String?

    public init() {
        // Public initializer
    }

    public var body: some View {
        VStack(spacing: DesignConstants.Spacing.large) {
            headerSection
            contentSection
        }
        .padding(DesignConstants.Spacing.large)
        .task {
            await loadPlugins()
        }
        #if os(iOS)
        .refreshable {
            await loadPlugins()
        }
        #endif
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: DesignConstants.Spacing.small) {
            Text("Plugins", bundle: .module)
                .font(.title2)
                .fontWeight(.semibold)
            Text("Review and approve plugins before they run.", bundle: .module)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Content

    @ViewBuilder private var contentSection: some View {
        if isLoading {
            ProgressView()
                .frame(maxWidth: .infinity, alignment: .center)
        } else if let errorMessage {
            ContentUnavailableView(
                "Unable to Load Plugins",
                systemImage: "exclamationmark.triangle.fill",
                description: Text(errorMessage)
            )
        } else if plugins.isEmpty {
            ContentUnavailableView(
                "No Plugins Found",
                systemImage: "puzzlepiece.extension",
                description: Text("Install plugins to manage approvals.", bundle: .module)
            )
        } else {
            List {
                if !pendingPlugins.isEmpty {
                    Section {
                        pendingSection()
                    } header: {
                        Text("Pending Approval", bundle: .module)
                    }
                }
                if !trustedPlugins.isEmpty {
                    Section {
                        trustedSection()
                    } header: {
                        Text("Trusted", bundle: .module)
                    }
                }
                if !blockedPlugins.isEmpty {
                    Section {
                        blockedSection()
                    } header: {
                        Text("Blocked", bundle: .module)
                    }
                }
            }
            #if os(macOS)
            .listStyle(.inset)
            #else
            .listStyle(.insetGrouped)
            #endif
        }
    }

    private func pendingSection() -> some View {
        ForEach(pendingPlugins) { entry in
            pluginRow(entry, showActions: true)
        }
    }

    private func trustedSection() -> some View {
        ForEach(trustedPlugins) { entry in
            pluginRow(entry, showActions: false)
        }
    }

    private func blockedSection() -> some View {
        ForEach(blockedPlugins) { entry in
            pluginRow(entry, showActions: false)
        }
    }

    private func pluginRow(_ entry: PluginCatalogEntry, showActions: Bool) -> some View {
        VStack(alignment: .leading, spacing: DesignConstants.Spacing.small) {
            pluginHeader(for: entry)
            pluginReason(for: entry)
            if showActions {
                pluginActions(for: entry)
            }
        }
        .padding(.vertical, DesignConstants.Spacing.small)
    }

    private func pluginHeader(for entry: PluginCatalogEntry) -> some View {
        HStack(alignment: .top, spacing: DesignConstants.Spacing.standard) {
            VStack(alignment: .leading, spacing: DesignConstants.Spacing.xSmall) {
                Text(entry.manifest.name)
                    .font(.headline)
                Text(entry.manifest.id)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(entry.manifest.version)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            statusBadge(for: entry.decision.level)
        }
    }

    @ViewBuilder
    private func pluginReason(for entry: PluginCatalogEntry) -> some View {
        if !entry.decision.reasons.isEmpty {
            Text(reasonText(for: entry))
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }

    private func reasonText(for entry: PluginCatalogEntry) -> String {
        entry.decision.reasons
            .map { $0.rawValue.replacingOccurrences(of: "_", with: " ") }
            .joined(separator: ", ")
    }

    private func pluginActions(for entry: PluginCatalogEntry) -> some View {
        HStack(spacing: DesignConstants.Spacing.standard) {
            Button {
                Task { await approve(entry) }
            } label: {
                Text("Approve", bundle: .module)
            }
            .buttonStyle(.borderedProminent)

            Button(role: .destructive) {
                Task { await deny(entry) }
            } label: {
                Text("Deny", bundle: .module)
            }
            .buttonStyle(.bordered)
        }
    }

    private func statusBadge(for level: PluginTrustLevel) -> some View {
        let title: String
        let symbol: String
        let color: Color

        switch level {
        case .requiresUserApproval:
            title = String(localized: "Pending Approval", bundle: .module)
            symbol = "exclamationmark.triangle.fill"
            color = .orange

        case .trusted:
            title = String(localized: "Trusted", bundle: .module)
            symbol = "checkmark.seal.fill"
            color = .green

        case .untrusted:
            title = String(localized: "Blocked", bundle: .module)
            symbol = "xmark.octagon.fill"
            color = .red
        }

        return Label(title, systemImage: symbol)
            .font(.caption)
            .foregroundStyle(color)
    }

    // MARK: - State

    private var pendingPlugins: [PluginCatalogEntry] {
        plugins.filter { $0.decision.level == .requiresUserApproval }
    }

    private var trustedPlugins: [PluginCatalogEntry] {
        plugins.filter { $0.decision.level == .trusted }
    }

    private var blockedPlugins: [PluginCatalogEntry] {
        plugins.filter { $0.decision.level == .untrusted }
    }

    private func loadPlugins() async {
        isLoading = true
        await pluginApprovalViewModel.loadPlugins()
        await refreshState()
        isLoading = false
    }

    private func refreshState() async {
        plugins = await pluginApprovalViewModel.plugins
        errorMessage = await pluginApprovalViewModel.errorMessage
    }

    private func approve(_ entry: PluginCatalogEntry) async {
        await pluginApprovalViewModel.approve(pluginId: entry.id)
        await refreshState()
    }

    private func deny(_ entry: PluginCatalogEntry) async {
        await pluginApprovalViewModel.deny(pluginId: entry.id)
        await refreshState()
    }
}

#if DEBUG
#Preview {
    PluginApprovalSettingsView()
}
#endif
