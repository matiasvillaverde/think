import ArgumentParser
import Foundation

struct OnboardCommand: AsyncParsableCommand, GlobalOptionsAccessing {
    static let configuration = CommandConfiguration(
        commandName: "onboard",
        abstract: "Guide through initial CLI setup."
    )

    @OptionGroup
    var global: GlobalOptions

    @ParentCommand
    var parent: ThinkCLI

    var parentGlobal: GlobalOptions? { parent.global }

    @Option(
        name: .customLong("workspace-path"),
        help: "Workspace root for skills and workspace tools."
    )
    var workspacePath: String?

    @Option(name: .long, help: "Model repository id or model UUID.")
    var model: String?

    @Option(name: .long, help: "Preferred backend (mlx, gguf, coreml, remote).")
    var backend: String?

    @Flag(name: .long, help: "Skip downloading the model.")
    var skipDownload: Bool = false

    @Option(
        name: .long,
        parsing: .upToNextOption,
        help: "Skills to enable (names or UUIDs)."
    )
    var skills: [String] = []

    @Flag(name: .long, help: "Do not prompt for missing values.")
    var nonInteractive: Bool = false

    func run() async throws {
        let runtime = try await CLIRuntimeProvider.runtime(for: resolvedGlobal)
        let input = StdInCLIInput()

        var resolvedWorkspace = workspacePath
        var resolvedModel = model
        var resolvedSkills = skills

        if !nonInteractive {
            if resolvedWorkspace == nil {
                resolvedWorkspace = readValue(
                    prompt: "Workspace path (enter to skip):",
                    input: input
                )
            }
            if resolvedModel == nil {
                resolvedModel = readValue(
                    prompt: "Model repo or UUID (enter to skip):",
                    input: input
                )
            }
            if resolvedSkills.isEmpty {
                if let value = readValue(
                    prompt: "Skills to enable (comma separated, enter to skip):",
                    input: input
                ) {
                    resolvedSkills = value
                        .split(separator: ",")
                        .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                        .filter { !$0.isEmpty }
                }
            }
        }

        let preferredBackend = try backend.map { try CLIParsing.parseBackend($0) }
        let options = CLIOnboarding.Options(
            workspace: resolvedWorkspace,
            model: resolvedModel,
            preferredBackend: preferredBackend,
            skipDownload: skipDownload,
            skills: resolvedSkills
        )

        let onboarding = CLIOnboarding()
        let result = try await onboarding.run(runtime: runtime, options: options)
        let fallback = [
            "Onboarding complete.",
            "workspace=\(result.workspacePath ?? "-")",
            "model=\(result.defaultModelId?.uuidString ?? "-")",
            "skills=\(result.enabledSkillIds.count)"
        ].joined(separator: " ")
        runtime.output.emit(result, fallback: fallback)
    }

    private func readValue(prompt: String, input: CLIInputting) -> String? {
        guard let line = input.readLine(prompt: prompt) else {
            return nil
        }
        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
