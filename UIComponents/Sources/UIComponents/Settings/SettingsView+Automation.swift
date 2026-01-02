import Abstractions
import Database
import SwiftUI

extension SettingsView {
    // MARK: - Voice View

    var voiceView: some View {
        VStack(alignment: .leading, spacing: Constants.sectionSpacing) {
            Text(String(
                localized: "Voice",
                bundle: .module,
                comment: "Voice settings title"
            ))
            .font(.title2)
            .fontWeight(.bold)

            Toggle(
                String(
                    localized: "Enable talk mode by default",
                    bundle: .module,
                    comment: "Toggle to enable talk mode"
                ),
                isOn: $talkModeEnabled
            )
            .onChange(of: talkModeEnabled) { _, newValue in
                Task {
                    _ = try? await database.write(
                        SettingsCommands.UpdateVoice(talkModeEnabled: .set(newValue))
                    )
                }
            }

            Toggle(
                String(
                    localized: "Require wake word",
                    bundle: .module,
                    comment: "Toggle to require wake word"
                ),
                isOn: $wakeWordEnabled
            )
            .onChange(of: wakeWordEnabled) { _, newValue in
                Task {
                    _ = try? await database.write(
                        SettingsCommands.UpdateVoice(wakeWordEnabled: .set(newValue))
                    )
                    await audioViewModel.setWakeWordEnabled(newValue)
                }
            }

            VStack(alignment: .leading, spacing: 8) {
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
                    text: $wakePhrase
                )
                .textFieldStyle(.roundedBorder)
                .onSubmit {
                    Task {
                        _ = try? await database.write(
                            SettingsCommands.UpdateVoice(wakePhrase: .set(wakePhrase))
                        )
                        await audioViewModel.updateWakePhrase(wakePhrase)
                    }
                }
            }

            Spacer()
        }
        .padding(Constants.contentPadding)
        .task {
            await refreshVoiceSettings()
        }
    }

    // MARK: - Automation View

    var automationView: some View {
        VStack(alignment: .leading, spacing: Constants.sectionSpacing) {
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

            if schedules.isEmpty {
                Text(String(
                    localized: "No schedules yet.",
                    bundle: .module,
                    comment: "No schedules message"
                ))
                .foregroundStyle(Color.textSecondary)
            } else {
                List {
                    ForEach(schedules) { schedule in
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(schedule.title)
                                    .font(.headline)
                                Text(schedule.prompt)
                                    .font(.caption)
                                    .foregroundStyle(Color.textSecondary)
                                if let nextRunAt = schedule.nextRunAt {
                                    Text(nextRunAt.formatted(date: .abbreviated, time: .shortened))
                                        .font(.caption2)
                                        .foregroundStyle(Color.textSecondary)
                                }
                            }
                            Spacer()
                            Toggle(
                                String(localized: "Enabled", bundle: .module),
                                isOn: Binding(
                                    get: { schedule.isEnabled },
                                    set: { newValue in
                                        Task {
                                            _ = try? await database.write(
                                                AutomationScheduleCommands.SetEnabled(
                                                    id: schedule.id,
                                                    isEnabled: newValue
                                                )
                                            )
                                        }
                                    }
                                )
                            )
                            .labelsHidden()
                        }
                    }
                }
                #if os(macOS)
                .frame(minHeight: 200)
                #endif
            }

            Spacer()
        }
        .padding(Constants.contentPadding)
    }

    // MARK: - Node Mode View

    var nodeModeView: some View {
        VStack(alignment: .leading, spacing: Constants.sectionSpacing) {
            Text(String(
                localized: "Node Mode",
                bundle: .module,
                comment: "Node mode settings title"
            ))
            .font(.title2)
            .fontWeight(.bold)

            Toggle(
                String(
                    localized: "Enable node mode",
                    bundle: .module,
                    comment: "Toggle to enable node mode"
                ),
                isOn: $nodeModeEnabled
            )
            .onChange(of: nodeModeEnabled) { _, newValue in
                Task {
                    await nodeModeViewModel.setEnabled(newValue)
                    await refreshNodeModeSettings()
                }
            }

            HStack(spacing: 12) {
                Text(String(
                    localized: "Port",
                    bundle: .module,
                    comment: "Port label"
                ))
                TextField("9876", text: $nodeModePort)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 120)
                    .onSubmit {
                        Task {
                            if let port = Int(nodeModePort) {
                                await nodeModeViewModel.updatePort(port)
                                await refreshNodeModeSettings()
                            }
                        }
                    }
            }

            HStack(spacing: 12) {
                Text(String(
                    localized: "Auth token",
                    bundle: .module,
                    comment: "Auth token label"
                ))
                SecureField("Optional", text: $nodeModeAuthToken)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit {
                        Task {
                            let token = nodeModeAuthToken.trimmingCharacters(in: .whitespacesAndNewlines)
                            await nodeModeViewModel.updateAuthToken(token.isEmpty ? nil : token)
                            await refreshNodeModeSettings()
                        }
                    }
            }

            HStack(spacing: 8) {
                Image(systemName: nodeModeRunning ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .foregroundStyle(nodeModeRunning ? Color.green : Color.red)
                Text(nodeModeRunning
                    ? String(localized: "Node mode running", bundle: .module)
                    : String(localized: "Node mode stopped", bundle: .module)
                )
                .font(.caption)
            }

            Spacer()
        }
        .padding(Constants.contentPadding)
        .task {
            await refreshNodeModeSettings()
        }
    }

    // MARK: - Helpers

    private func refreshVoiceSettings() async {
        do {
            let settings = try await database.read(SettingsCommands.GetOrCreate())
            await MainActor.run {
                talkModeEnabled = settings.talkModeEnabled
                wakeWordEnabled = settings.wakeWordEnabled
                wakePhrase = settings.wakePhrase
            }
        } catch {
            // Ignore in UI
        }
    }

    private func refreshNodeModeSettings() async {
        await nodeModeViewModel.refresh()
        let enabled = await nodeModeViewModel.isEnabled
        let port = await nodeModeViewModel.port
        let token = await nodeModeViewModel.authToken
        let running = await nodeModeViewModel.isRunning

        await MainActor.run {
            nodeModeEnabled = enabled
            nodeModePort = String(port)
            nodeModeAuthToken = token ?? ""
            nodeModeRunning = running
        }
    }
}
