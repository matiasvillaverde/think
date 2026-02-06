import Abstractions
import ArgumentParser
import Database
import Foundation

struct CLIOnboarding {
    struct Options: Sendable {
        let workspace: String?
        let model: String?
        let preferredBackend: SendableModel.Backend?
        let skipDownload: Bool
        let skills: [String]
    }

    struct Result: Codable, Equatable, Sendable {
        let workspacePath: String?
        let defaultModelId: UUID?
        let enabledSkillIds: [UUID]
    }

    let configStore: CLIConfigStore
    let fileManager: FileManager
    let dateProvider: () -> Date

    init(
        configStore: CLIConfigStore = CLIConfigStore(),
        fileManager: FileManager = .default,
        dateProvider: @escaping () -> Date = Date.init
    ) {
        self.configStore = configStore
        self.fileManager = fileManager
        self.dateProvider = dateProvider
    }

    func run(runtime: CLIRuntime, options: Options) async throws -> Result {
        var config = configStore.loadOrDefault()
        config = try applyWorkspace(options.workspace, config: config)
        config = try await applyModel(options, runtime: runtime, config: config)
        let skillResult = try await applySkills(options.skills, runtime: runtime, config: config)
        config = skillResult.config
        config.lastOnboardedAt = dateProvider()
        try configStore.save(config)

        return Result(
            workspacePath: config.workspacePath,
            defaultModelId: config.defaultModelId,
            enabledSkillIds: skillResult.enabledSkillIds
        )
    }

    func applyWorkspace(_ workspace: String?, config: CLIConfig) throws -> CLIConfig {
        guard let workspace,
              !workspace.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return config
        }

        let url = URL(fileURLWithPath: workspace)
        try fileManager.createDirectory(at: url, withIntermediateDirectories: true)

        var updated = config
        updated.workspacePath = url.path
        return updated
    }

    func applyModel(
        _ options: Options,
        runtime: CLIRuntime,
        config: CLIConfig
    ) async throws -> CLIConfig {
        guard let model = options.model, !model.isEmpty else {
            return config
        }

        if let uuid = UUID(uuidString: model) {
            _ = try await runtime.database.read(ModelCommands.GetSendableModel(id: uuid))
            var updated = config
            updated.defaultModelId = uuid
            return updated
        }

        let explorer = runtime.downloader.explorer()
        let discovered = try await explorer.discoverModel(model)
        let sendable = try await explorer.prepareForDownload(
            discovered,
            preferredBackend: options.preferredBackend
        )

        let createCommand = await MainActor.run {
            ModelCommands.CreateFromDiscovery(
                discoveredModel: discovered,
                sendableModel: sendable
            )
        }
        let modelId = try await runtime.database.write(createCommand)

        var updated = config
        updated.defaultModelId = modelId

        guard !options.skipDownload else {
            return updated
        }

        runtime.output.emit("Downloading \(sendable.location)...")

        for try await event in runtime.downloader.download(sendableModel: sendable) {
            switch event {
            case .progress(let progress):
                try await runtime.database.write(
                    ModelCommands.UpdateModelDownloadProgress(
                        id: sendable.id,
                        progress: progress.fractionCompleted
                    )
                )
                runtime.output.emit(progress.description)
            case .completed(let info):
                _ = try await runtime.database.write(
                    ModelCommands.UpdateModelDownloadProgress(id: sendable.id, progress: 1.0)
                )
                runtime.output.emit(
                    "Download completed: \(info.name) (\(info.backend.rawValue))"
                )
            }
        }

        return updated
    }

    func applySkills(
        _ skills: [String],
        runtime: CLIRuntime,
        config: CLIConfig
    ) async throws -> (config: CLIConfig, enabledSkillIds: [UUID]) {
        guard !skills.isEmpty else {
            return (config, [])
        }

        let enabled = try await Self.resolveAndEnableSkills(
            skills,
            runtime: runtime
        )

        var updated = config
        updated.preferredSkills = skills
        return (updated, enabled)
    }

    @MainActor
    private static func resolveAndEnableSkills(
        _ skills: [String],
        runtime: CLIRuntime
    ) async throws -> [UUID] {
        let existingSkills = try await runtime.database.read(SkillCommands.GetAll())
        var enabled: [UUID] = []
        var missing: [String] = []

        for entry in skills {
            if let uuid = UUID(uuidString: entry),
               existingSkills.contains(where: { $0.id == uuid }) {
                enabled.append(uuid)
                continue
            }

            if let skill = existingSkills.first(where: {
                $0.name.lowercased() == entry.lowercased()
            }) {
                enabled.append(skill.id)
                continue
            }

            missing.append(entry)
        }

        if !missing.isEmpty {
            throw ValidationError("Unknown skills: \(missing.joined(separator: ", "))")
        }

        for skillId in enabled {
            _ = try await runtime.database.write(
                SkillCommands.SetEnabled(skillId: skillId, isEnabled: true)
            )
        }

        return enabled
    }
}
