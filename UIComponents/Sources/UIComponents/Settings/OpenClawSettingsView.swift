import Abstractions
import SwiftUI

public struct OpenClawSettingsView: View {
    enum Constants {
        static let contentPadding: CGFloat = 0
        static let sectionSpacing: CGFloat = 16
        static let smallSpacing: CGFloat = 6
        static let cardCornerRadius: CGFloat = 16
        static let cardPadding: CGFloat = 14
        static let cardStrokeOpacity: Double = 0.16
        static let headerHStackSpacing: CGFloat = 12
        static let headerImageSize: CGFloat = 36
        static let headerVStackSpacing: CGFloat = 2
        static let cardInnerSpacing: CGFloat = 10

        static let headerSubtitle: String.LocalizationValue =
            "Add one or more remote OpenClaw Gateway instances (WebSocket) and test connectivity."
    }

    @Environment(\.openClawInstancesViewModel)
    private var viewModel: OpenClawInstancesViewModeling

    @State private var instances: [OpenClawInstanceRecord] = []
    @State private var statuses: [UUID: OpenClawConnectionStatus] = [:]

    @State private var name: String = ""
    @State private var urlString: String = ""
    @State private var authToken: String = ""
    @State private var errorMessage: String?

    public var body: some View {
        VStack(alignment: .leading, spacing: Constants.sectionSpacing) {
            header

            if let errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundStyle(Color.paletteRed)
            }

            instancesCard
            addInstanceCard

            Spacer()
        }
        .padding(Constants.contentPadding)
        .task { await refresh() }
    }

    private var header: some View {
        HStack(spacing: Constants.headerHStackSpacing) {
            Image(ImageResource(name: "openclaw-claw", bundle: .module))
                .resizable()
                .scaledToFit()
                .frame(width: Constants.headerImageSize, height: Constants.headerImageSize)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: Constants.headerVStackSpacing) {
                Text(String(localized: "OpenClaw Gateway", bundle: .module))
                    .font(.title2)
                    .fontWeight(.bold)

                Text(String(localized: Constants.headerSubtitle, bundle: .module))
                    .font(.caption)
                    .foregroundStyle(Color.textSecondary)
            }

            Spacer(minLength: 0)
        }
    }

    private var instancesCard: some View {
        VStack(alignment: .leading, spacing: Constants.cardInnerSpacing) {
            Text(String(localized: "Instances", bundle: .module))
                .font(.headline)
                .foregroundStyle(Color.textPrimary)

            OpenClawInstancesListView(
                instances: instances,
                statuses: statuses,
                onUse: { id in Task { await useInstance(id: id) } },
                onTest: { id in Task { await testInstance(id: id) } },
                onDelete: { id in Task { await deleteInstance(id: id) } }
            )
        }
        .padding(Constants.cardPadding)
        .background(Color.backgroundSecondary)
        .overlay(
            RoundedRectangle(cornerRadius: Constants.cardCornerRadius)
                .stroke(Color.textSecondary.opacity(Constants.cardStrokeOpacity), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: Constants.cardCornerRadius))
    }

    private var addInstanceCard: some View {
        VStack(alignment: .leading, spacing: Constants.cardInnerSpacing) {
            Text(String(localized: "Add Instance", bundle: .module))
                .font(.headline)
                .foregroundStyle(Color.textPrimary)

            OpenClawAddInstanceFormView(
                name: $name,
                urlString: $urlString,
                authToken: $authToken,
                onSave: { Task { await saveNewInstance() } },
                onRefresh: { Task { await refresh() } }
            )
        }
        .padding(Constants.cardPadding)
        .background(Color.backgroundSecondary)
        .overlay(
            RoundedRectangle(cornerRadius: Constants.cardCornerRadius)
                .stroke(Color.textSecondary.opacity(Constants.cardStrokeOpacity), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: Constants.cardCornerRadius))
    }

    private func refresh() async {
        await viewModel.refresh()
        let newInstances: [OpenClawInstanceRecord] = await viewModel.instances
        let newStatuses: [UUID: OpenClawConnectionStatus] = await viewModel.connectionStatuses
        await MainActor.run {
            instances = newInstances
            statuses = newStatuses
        }
    }

    private func refreshStatuses() async {
        let newStatuses: [UUID: OpenClawConnectionStatus] = await viewModel.connectionStatuses
        await MainActor.run {
            statuses = newStatuses
        }
    }

    private func useInstance(id: UUID) async {
        do {
            try await viewModel.setActiveInstance(id: id)
            await refresh()
        } catch {
            await MainActor.run { errorMessage = error.localizedDescription }
        }
    }

    private func testInstance(id: UUID) async {
        await viewModel.testConnection(id: id)
        await refreshStatuses()
    }

    private func deleteInstance(id: UUID) async {
        do {
            try await viewModel.deleteInstance(id: id)
            await refresh()
        } catch {
            await MainActor.run { errorMessage = error.localizedDescription }
        }
    }

    private func saveNewInstance() async {
        do {
            try await viewModel.upsertInstance(
                id: nil,
                name: name,
                urlString: urlString,
                authToken: authToken.isEmpty ? nil : authToken
            )
            await MainActor.run {
                name = ""
                urlString = ""
                authToken = ""
                errorMessage = nil
            }
            await refresh()
        } catch {
            await MainActor.run { errorMessage = error.localizedDescription }
        }
    }
}

private struct OpenClawInstancesListView: View {
    enum Constants {
        static let rowSpacing: CGFloat = 10
        static let smallSpacing: CGFloat = 6
        static let actionsSpacing: CGFloat = 10
        static let instanceRowVerticalPadding: CGFloat = 6

        static let badgeHorizontalPadding: CGFloat = 8
        static let badgeVerticalPadding: CGFloat = 2
        static let badgeBackgroundOpacity: CGFloat = 0.15

        static let statusDotSize: CGFloat = 8
        static let statusDotSpacing: CGFloat = 6
    }

    let instances: [OpenClawInstanceRecord]
    let statuses: [UUID: OpenClawConnectionStatus]
    let onUse: (UUID) -> Void
    let onTest: (UUID) -> Void
    let onDelete: (UUID) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Constants.rowSpacing) {
            if instances.isEmpty {
                Text(String(localized: "No instances configured.", bundle: .module))
                    .font(.caption)
                    .foregroundStyle(Color.textSecondary)
            } else {
                ForEach(instances) { instance in
                    instanceRow(instance)
                        .padding(.vertical, Constants.instanceRowVerticalPadding)
                    if instance.id != instances.last?.id {
                        Divider()
                    }
                }
            }
        }
    }

    private func instanceRow(_ instance: OpenClawInstanceRecord) -> some View {
        VStack(alignment: .leading, spacing: Constants.smallSpacing) {
            HStack(spacing: Constants.actionsSpacing) {
                instanceTitle(instance)
                Spacer()
                instanceActions(instance)
            }

            Text(instance.urlString)
                .font(.caption)
                .foregroundStyle(Color.textSecondary)

            let status: OpenClawConnectionStatus = statuses[instance.id] ?? .idle
            statusLine(status)
        }
    }

    private func instanceTitle(_ instance: OpenClawInstanceRecord) -> some View {
        HStack(spacing: Constants.actionsSpacing) {
            Text(instance.name)
                .font(.headline)
            if instance.isActive {
                Text(String(localized: "Active", bundle: .module))
                    .font(.caption2)
                    .padding(.horizontal, Constants.badgeHorizontalPadding)
                    .padding(.vertical, Constants.badgeVerticalPadding)
                    .background(Color.accentColor.opacity(Constants.badgeBackgroundOpacity))
                    .clipShape(Capsule())
            }
        }
    }

    private func instanceActions(_ instance: OpenClawInstanceRecord) -> some View {
        HStack(spacing: Constants.actionsSpacing) {
            Button(String(localized: "Use", bundle: .module)) {
                onUse(instance.id)
            }
            .buttonStyle(.bordered)

            Button(String(localized: "Test", bundle: .module)) {
                onTest(instance.id)
            }
            .buttonStyle(.bordered)

            Button(role: .destructive) {
                onDelete(instance.id)
            } label: {
                Text(String(localized: "Delete", bundle: .module))
            }
            .buttonStyle(.bordered)
        }
    }

    private func statusLine(_ status: OpenClawConnectionStatus) -> some View {
        HStack(spacing: Constants.statusDotSpacing) {
            Circle()
                .fill(color(for: status))
                .frame(width: Constants.statusDotSize, height: Constants.statusDotSize)
            Text(statusText(status))
                .font(.caption)
                .foregroundStyle(Color.textSecondary)
        }
    }

    private func color(for status: OpenClawConnectionStatus) -> Color {
        switch status {
        case .idle:
            return .gray

        case .connecting:
            return .orange

        case .connected:
            return .green

        case .pairingRequired:
            return .orange

        case .failed:
            return .red
        }
    }

    private func statusText(_ status: OpenClawConnectionStatus) -> String {
        switch status {
        case .idle:
            return String(localized: "Not tested", bundle: .module)

        case .connecting:
            return String(localized: "Connecting…", bundle: .module)

        case .connected:
            return String(localized: "Connected", bundle: .module)

        case .pairingRequired(let requestId):
            return String(localized: "Pairing required (request: \(requestId))", bundle: .module)

        case .failed(let message):
            return String(localized: "Failed: \(message)", bundle: .module)
        }
    }
}

private struct OpenClawAddInstanceFormView: View {
    enum Constants {
        static let addFormSpacing: CGFloat = 12
        static let fieldSpacing: CGFloat = 6
        static let actionsSpacing: CGFloat = 10
    }

    @Binding var name: String
    @Binding var urlString: String
    @Binding var authToken: String

    let onSave: () -> Void
    let onRefresh: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Constants.addFormSpacing) {
            nameRow
            urlRow
            tokenRow
            buttonsRow
        }
    }
    private var nameRow: some View {
        VStack(alignment: .leading, spacing: Constants.fieldSpacing) {
            Text(String(localized: "Name", bundle: .module))
                .font(.caption)
                .foregroundStyle(Color.textSecondary)
            TextField(String(localized: "My OpenClaw", bundle: .module), text: $name)
                .textFieldStyle(.roundedBorder)
        }
    }
    private var urlRow: some View {
        VStack(alignment: .leading, spacing: Constants.fieldSpacing) {
            Text(String(localized: "URL", bundle: .module))
                .font(.caption)
                .foregroundStyle(Color.textSecondary)
            TextField(
                "",
                text: $urlString,
                prompt: Text(
                    "wss://host.example/gateway",
                    bundle: .module
                )
            )
            .textFieldStyle(.roundedBorder)
            #if os(iOS)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
            #endif
        }
    }
    private var tokenRow: some View {
        VStack(alignment: .leading, spacing: Constants.fieldSpacing) {
            Text(String(localized: "Token", bundle: .module))
                .font(.caption)
                .foregroundStyle(Color.textSecondary)
            SecureField(String(localized: "Optional", bundle: .module), text: $authToken)
                .textFieldStyle(.roundedBorder)
            #if os(iOS)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
            #endif
        }
    }

    private var buttonsRow: some View {
        HStack(spacing: Constants.actionsSpacing) {
            Button(String(localized: "Save", bundle: .module)) {
                onSave()
            }
            .buttonStyle(.borderedProminent)

            Button(String(localized: "Refresh", bundle: .module)) {
                onRefresh()
            }
            .buttonStyle(.bordered)
        }
    }
}
