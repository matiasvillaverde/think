import Abstractions
import SwiftUI

public struct OpenClawSettingsView: View {
    enum Constants {
        static let contentPadding: CGFloat = 16
        static let sectionSpacing: CGFloat = 16
        static let smallSpacing: CGFloat = 6

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
                    .foregroundStyle(Color.red)
            }

            OpenClawInstancesListView(
                instances: instances,
                statuses: statuses,
                onUse: { id in Task { await useInstance(id: id) } },
                onTest: { id in Task { await testInstance(id: id) } },
                onDelete: { id in Task { await deleteInstance(id: id) } }
            )

            Divider()

            OpenClawAddInstanceFormView(
                name: $name,
                urlString: $urlString,
                authToken: $authToken,
                onSave: { Task { await saveNewInstance() } },
                onRefresh: { Task { await refresh() } }
            )

            Spacer()
        }
        .padding(Constants.contentPadding)
        .task { await refresh() }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: Constants.smallSpacing) {
            Text(String(localized: "OpenClaw Remote", bundle: .module))
                .font(.title2)
                .fontWeight(.bold)
            Text(String(localized: Constants.headerSubtitle, bundle: .module))
                .font(.caption)
                .foregroundStyle(Color.secondary)
        }
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
                    .foregroundStyle(Color.secondary)
            } else {
                ForEach(instances) { instance in
                    instanceRow(instance)
                        .padding(.vertical, Constants.instanceRowVerticalPadding)
                    Divider()
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
                .foregroundStyle(Color.secondary)

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
                .foregroundStyle(Color.secondary)
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
            return String(localized: "Pairing required: \(requestId)", bundle: .module)

        case .failed(let message):
            return String(localized: "Failed: \(message)", bundle: .module)
        }
    }
}

private struct OpenClawAddInstanceFormView: View {
    enum Constants {
        static let addFormSpacing: CGFloat = 10
        static let actionsSpacing: CGFloat = 10
        static let labelWidth: CGFloat = 80
        static let fieldWidth: CGFloat = 260
        static let extendedFieldExtraWidth: CGFloat = 200
    }

    @Binding var name: String
    @Binding var urlString: String
    @Binding var authToken: String

    let onSave: () -> Void
    let onRefresh: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Constants.addFormSpacing) {
            titleRow
            nameRow
            urlRow
            tokenRow
            buttonsRow
        }
    }

    private var titleRow: some View {
        Text(String(localized: "Add Instance", bundle: .module))
            .font(.headline)
    }

    private var nameRow: some View {
        HStack(spacing: Constants.actionsSpacing) {
            Text(String(localized: "Name", bundle: .module))
                .frame(width: Constants.labelWidth, alignment: .leading)
            TextField(String(localized: "My OpenClaw", bundle: .module), text: $name)
                .textFieldStyle(.roundedBorder)
                .frame(width: Constants.fieldWidth)
        }
    }

    private var urlRow: some View {
        HStack(spacing: Constants.actionsSpacing) {
            Text(String(localized: "URL", bundle: .module))
                .frame(width: Constants.labelWidth, alignment: .leading)
            TextField("wss://host.example/gateway", text: $urlString)
                .textFieldStyle(.roundedBorder)
                .frame(width: Constants.fieldWidth + Constants.extendedFieldExtraWidth)
        }
    }

    private var tokenRow: some View {
        HStack(spacing: Constants.actionsSpacing) {
            Text(String(localized: "Token", bundle: .module))
                .frame(width: Constants.labelWidth, alignment: .leading)
            SecureField(String(localized: "Optional", bundle: .module), text: $authToken)
                .textFieldStyle(.roundedBorder)
                .frame(width: Constants.fieldWidth + Constants.extendedFieldExtraWidth)
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
