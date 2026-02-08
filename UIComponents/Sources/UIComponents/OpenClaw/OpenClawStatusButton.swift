import Abstractions
import SwiftUI

public struct OpenClawStatusButton: View {
    private enum Layout {
        static let dotSize: CGFloat = 8
        static let dotOffsetX: CGFloat = 9
        static let dotOffsetY: CGFloat = 9
    }

    @Environment(\.openClawInstancesViewModel)
    private var viewModel: OpenClawInstancesViewModeling

    @Binding private var isSettingsPresented: Bool

    @State private var activeInstance: OpenClawInstanceRecord?
    @State private var status: OpenClawConnectionStatus = .idle

    public init(isSettingsPresented: Binding<Bool>) {
        self._isSettingsPresented = isSettingsPresented
    }

    public var body: some View {
        Menu {
            menuContent
        } label: {
            label
        }
        .accessibilityLabel(Text(style.label))
        .task {
            await refreshState()
        }
    }

    private var menuContent: some View {
        Group {
            if let activeInstance {
                activeMenuContent(activeInstance: activeInstance)
            } else {
                inactiveMenuContent
            }
        }
    }

    private func activeMenuContent(activeInstance: OpenClawInstanceRecord) -> some View {
        Group {
            Text("Active: \(activeInstance.name)")
            Text(activeInstance.urlString)
                .font(.caption)
                .foregroundStyle(Color.secondary)

            Divider()

            Text(statusText(status))
                .font(.caption)

            if case .pairingRequired(let requestId) = status {
                Text("requestId: \(requestId)")
                    .font(.caption2)
                    .foregroundStyle(Color.secondary)
            }

            Divider()

            Button("Test Connection") {
                Task { await testActiveConnection() }
            }

            Button("Manage Instances") {
                isSettingsPresented = true
            }

            Button("Deactivate") {
                Task { await deactivate() }
            }
        }
    }

    private var inactiveMenuContent: some View {
        Group {
            Text("No OpenClaw instance selected.")
                .font(.caption)

            Divider()

            Button("Manage Instances") {
                isSettingsPresented = true
            }
        }
    }

    private var label: some View {
        ZStack {
            Image(systemName: style.symbolName)
                .accessibilityHidden(true)

            Circle()
                .fill(levelColor(style.level))
                .frame(width: Layout.dotSize, height: Layout.dotSize)
                .offset(x: Layout.dotOffsetX, y: -Layout.dotOffsetY)
                .opacity(activeInstance == nil ? 0 : 1)
                .accessibilityHidden(true)
        }
        .help(style.label)
    }

    private var style: OpenClawStatusStyle {
        OpenClawStatusPresenter.style(
            hasActiveInstance: activeInstance != nil,
            status: status
        )
    }

    private func levelColor(_ level: OpenClawStatusLevel) -> Color {
        switch level {
        case .neutral:
            return .gray

        case .success:
            return .green

        case .error:
            return .red

        case .warning:
            return .orange
        }
    }

    private func statusText(_ status: OpenClawConnectionStatus) -> String {
        switch status {
        case .idle:
            return "Status: idle"

        case .connecting:
            return "Status: connecting"

        case .connected:
            return "Status: connected"

        case .pairingRequired:
            return "Status: pairing required"

        case .failed(let message):
            return "Status: failed (\(message))"
        }
    }

    private func refreshState() async {
        await viewModel.refresh()
        let instances: [OpenClawInstanceRecord] = await viewModel.instances
        let statuses: [UUID: OpenClawConnectionStatus] = await viewModel.connectionStatuses

        let active: OpenClawInstanceRecord? = instances.first(where: \.isActive)
        let newStatus: OpenClawConnectionStatus = active.map { statuses[$0.id] ?? .idle } ?? .idle

        await MainActor.run {
            activeInstance = active
            status = newStatus
        }
    }

    private func testActiveConnection() async {
        guard let id: UUID = activeInstance?.id else {
            await refreshState()
            return
        }
        await viewModel.testConnection(id: id)
        await refreshState()
    }

    private func deactivate() async {
        do {
            try await viewModel.setActiveInstance(id: nil)
        } catch {
            // No-op for now: Settings screen shows errors; toolbar keeps UI minimal.
        }
        await refreshState()
    }
}

#if DEBUG
    #Preview {
        @Previewable @State var settingsPresented: Bool = false
        OpenClawStatusButton(isSettingsPresented: $settingsPresented)
            .padding()
    }
#endif
