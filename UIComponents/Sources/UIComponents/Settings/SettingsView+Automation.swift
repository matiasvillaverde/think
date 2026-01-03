import Abstractions
import Database
import SwiftUI

extension SettingsView {
    // MARK: - Voice View

    var voiceView: some View {
        VStack(alignment: .leading, spacing: Constants.sectionSpacing) {
            voiceHeader
            talkModeToggle
            wakeWordToggle
            wakePhraseSection
            Spacer()
        }
        .padding(Constants.contentPadding)
        .task {
            await refreshVoiceSettings()
        }
    }

    private var voiceHeader: some View {
        Text(String(
            localized: "Voice",
            bundle: .module,
            comment: "Voice settings title"
        ))
        .font(.title2)
        .fontWeight(.bold)
    }

    private var talkModeToggle: some View {
        Toggle(
            String(
                localized: "Enable talk mode by default",
                bundle: .module,
                comment: "Toggle to enable talk mode"
            ),
            isOn: talkModeEnabledBinding
        )
        .onChange(of: talkModeEnabledValue) { _, newValue in
            handleTalkModeChanged(newValue)
        }
    }

    private var wakeWordToggle: some View {
        Toggle(
            String(
                localized: "Require wake word",
                bundle: .module,
                comment: "Toggle to require wake word"
            ),
            isOn: wakeWordEnabledBinding
        )
        .onChange(of: wakeWordEnabledValue) { _, newValue in
            handleWakeWordChanged(newValue)
        }
    }

    private var wakePhraseSection: some View {
        VStack(alignment: .leading, spacing: Constants.compactSpacing) {
            Text(String(
                localized: "Wake phrase",
                bundle: .module,
                comment: "Label for wake phrase"
            ))
            TextField(
                String(
                    localized: "e.g. hey think",
                    bundle: .module,
                    comment: "Placeholder for wake phrase"
                ),
                text: wakePhraseBinding
            )
            .textFieldStyle(.roundedBorder)
            .onSubmit {
                handleWakePhraseSubmitted(wakePhraseValue)
            }
        }
    }

    private func handleTalkModeChanged(_ newValue: Bool) {
        Task {
            _ = try? await database.write(
                SettingsCommands.UpdateVoice(talkModeEnabled: .set(newValue))
            )
        }
    }

    private func handleWakeWordChanged(_ newValue: Bool) {
        Task {
            _ = try? await database.write(
                SettingsCommands.UpdateVoice(wakeWordEnabled: .set(newValue))
            )
            await audioViewModel.setWakeWordEnabled(newValue)
        }
    }

    private func handleWakePhraseSubmitted(_ phrase: String) {
        Task {
            _ = try? await database.write(
                SettingsCommands.UpdateVoice(wakePhrase: .set(phrase))
            )
            await audioViewModel.updateWakePhrase(phrase)
        }
    }

    // MARK: - Automation View

    var automationView: some View {
        VStack(alignment: .leading, spacing: Constants.sectionSpacing) {
            automationHeader
            automationList
            Spacer()
        }
        .padding(Constants.contentPadding)
    }

    private var automationHeader: some View {
        VStack(alignment: .leading, spacing: Constants.compactSpacing) {
            Text(String(
                localized: "Automation",
                bundle: .module,
                comment: "Automation settings title"
            ))
            .font(.title2)
            .fontWeight(.bold)

            Text(String(
                localized: "Schedules are created by the cron tool.",
                bundle: .module,
                comment: "Automation info"
            ))
            .foregroundStyle(Color.textSecondary)
        }
    }

    @ViewBuilder private var automationList: some View {
        if schedules.isEmpty {
            automationEmptyState
        } else {
            automationScheduleList
        }
    }

    private var automationEmptyState: some View {
        Text(String(
            localized: "No schedules yet.",
            bundle: .module,
            comment: "No schedules message"
        ))
        .foregroundStyle(Color.textSecondary)
    }

    private var automationScheduleList: some View {
        List {
            ForEach(schedules) { schedule in
                automationScheduleRow(schedule)
            }
        }
        #if os(macOS)
        .frame(minHeight: Constants.automationListMinHeight)
        #endif
    }

    private func automationScheduleRow(_ schedule: AutomationSchedule) -> some View {
        HStack {
            scheduleDetailsView(schedule)
            Spacer()
            scheduleToggle(schedule)
        }
    }

    private func scheduleDetailsView(_ schedule: AutomationSchedule) -> some View {
        VStack(alignment: .leading, spacing: Constants.tightSpacing) {
            Text(schedule.title)
                .font(.headline)
            Text(schedule.prompt)
                .font(.caption)
                .foregroundStyle(Color.textSecondary)
            if let nextRunAt: Date = schedule.nextRunAt {
                Text(nextRunAt.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption2)
                    .foregroundStyle(Color.textSecondary)
            }
        }
    }

    private func scheduleToggle(_ schedule: AutomationSchedule) -> some View {
        let enabledBinding: Binding<Bool> = Binding(
            get: { schedule.isEnabled },
            set: { newValue in
                handleScheduleEnabledChange(id: schedule.id, isEnabled: newValue)
            }
        )

        return Toggle(
            String(localized: "Enabled", bundle: .module),
            isOn: enabledBinding
        )
        .labelsHidden()
    }

    private func handleScheduleEnabledChange(id: UUID, isEnabled: Bool) {
        Task {
            _ = try? await database.write(
                AutomationScheduleCommands.SetEnabled(
                    id: id,
                    isEnabled: isEnabled
                )
            )
        }
    }

    // MARK: - Node Mode View

    var nodeModeView: some View {
        VStack(alignment: .leading, spacing: Constants.sectionSpacing) {
            nodeModeHeader
            nodeModeToggleRow
            nodeModePortRow
            nodeModeAuthRow
            nodeModeStatusRow
            Spacer()
        }
        .padding(Constants.contentPadding)
        .task {
            await refreshNodeModeSettings()
        }
    }

    private var nodeModeHeader: some View {
        Text(String(
            localized: "Node Mode",
            bundle: .module,
            comment: "Node mode settings title"
        ))
        .font(.title2)
        .fontWeight(.bold)
    }

    private var nodeModeToggleRow: some View {
        Toggle(
            String(
                localized: "Enable node mode",
                bundle: .module,
                comment: "Toggle to enable node mode"
            ),
            isOn: nodeModeEnabledBinding
        )
        .onChange(of: nodeModeEnabledValue) { _, newValue in
            handleNodeModeEnabledChanged(newValue)
        }
    }

    private var nodeModePortRow: some View {
        HStack(spacing: Constants.actionSpacing) {
            Text(String(
                localized: "Port",
                bundle: .module,
                comment: "Port label"
            ))
            TextField("9876", text: nodeModePortBinding)
                .textFieldStyle(.roundedBorder)
                .frame(width: Constants.portFieldWidth)
                .onSubmit {
                    handlePortSubmitted()
                }
        }
    }

    private var nodeModeAuthRow: some View {
        HStack(spacing: Constants.actionSpacing) {
            Text(String(
                localized: "Auth token",
                bundle: .module,
                comment: "Auth token label"
            ))
            SecureField("Optional", text: nodeModeAuthTokenBinding)
                .textFieldStyle(.roundedBorder)
                .onSubmit {
                    handleAuthTokenSubmitted()
                }
        }
    }

    private var nodeModeStatusRow: some View {
        HStack(spacing: Constants.compactSpacing) {
            Image(systemName: nodeModeRunningValue ? "checkmark.circle.fill" : "xmark.circle.fill")
                .foregroundStyle(nodeModeRunningValue ? Color.green : Color.red)
            Text(
                nodeModeRunningValue
                    ? String(localized: "Node mode running", bundle: .module)
                    : String(localized: "Node mode stopped", bundle: .module)
            )
            .font(.caption)
        }
    }

    private func handleNodeModeEnabledChanged(_ newValue: Bool) {
        Task {
            await nodeModeViewModel.setEnabled(newValue)
            await refreshNodeModeSettings()
        }
    }

    private func handlePortSubmitted() {
        Task {
            guard let portValue: Int = Int(nodeModePortValue) else {
                return
            }
            await nodeModeViewModel.updatePort(portValue)
            await refreshNodeModeSettings()
        }
    }

    private func handleAuthTokenSubmitted() {
        Task {
            let token: String = nodeModeAuthTokenValue.trimmingCharacters(
                in: .whitespacesAndNewlines
            )
            let trimmedToken: String? = token.isEmpty ? nil : token
            await nodeModeViewModel.updateAuthToken(trimmedToken)
            await refreshNodeModeSettings()
        }
    }

    // MARK: - Helpers

    private func refreshVoiceSettings() async {
        do {
            let settings: AppSettings = try await database.read(SettingsCommands.GetOrCreate())
            await MainActor.run {
                talkModeEnabledValue = settings.talkModeEnabled
                wakeWordEnabledValue = settings.wakeWordEnabled
                wakePhraseValue = settings.wakePhrase
            }
        } catch {
            // Ignore in UI
        }
    }

    private func refreshNodeModeSettings() async {
        await nodeModeViewModel.refresh()
        let enabled: Bool = await nodeModeViewModel.isEnabled
        let port: Int = await nodeModeViewModel.port
        let token: String? = await nodeModeViewModel.authToken
        let running: Bool = await nodeModeViewModel.isRunning

        await MainActor.run {
            nodeModeEnabledValue = enabled
            nodeModePortValue = String(port)
            nodeModeAuthTokenValue = token ?? ""
            nodeModeRunningValue = running
        }
    }
}
