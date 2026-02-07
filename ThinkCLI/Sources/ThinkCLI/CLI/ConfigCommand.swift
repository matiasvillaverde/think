import ArgumentParser
import Foundation

struct ConfigCommand: AsyncParsableCommand, GlobalOptionsAccessing {
    static let configuration = CommandConfiguration(
        commandName: "config",
        abstract: "View or update CLI configuration.",
        subcommands: [Show.self, Set.self, Reset.self, Resolve.self],
        defaultSubcommand: Show.self
    )

    @OptionGroup
    var global: GlobalOptions

    @ParentCommand
    var parent: ThinkCLI

    var parentGlobal: GlobalOptions? { parent.global }
}

extension ConfigCommand {
    struct Show: AsyncParsableCommand, GlobalOptionsAccessing {
        static let configuration = CommandConfiguration(
            abstract: "Show the current CLI configuration."
        )

        @OptionGroup
        var global: GlobalOptions

        @ParentCommand
        var parent: ConfigCommand

        var parentGlobal: GlobalOptions? { parent.resolvedGlobal }

        func run() async throws {
            let store = CLIConfigStore()
            let config = store.loadOrDefault()
            let output = CLIOutput(
                writer: StdoutOutput(),
                format: resolvedGlobal.resolvedOutputFormat
            )
            let skills = config.preferredSkills.joined(separator: ", ")
            let fallback = [
                "workspace=\(config.workspacePath ?? "-")",
                "model=\(config.defaultModelId?.uuidString ?? "-")",
                "skills=\(skills)"
            ].joined(separator: " ")
            output.emit(config, fallback: fallback)
        }
    }

    struct Set: AsyncParsableCommand, GlobalOptionsAccessing {
        static let configuration = CommandConfiguration(
            abstract: "Update CLI configuration values."
        )

        @OptionGroup
        var global: GlobalOptions

        @ParentCommand
        var parent: ConfigCommand

        var parentGlobal: GlobalOptions? { parent.resolvedGlobal }

        @Option(name: .customLong("workspace-path"), help: "Workspace path to set.")
        var workspace: String?

        @Flag(name: .long, help: "Clear the workspace path.")
        var clearWorkspace: Bool = false

        @Option(name: .long, help: "Default model UUID to set.")
        var modelId: String?

        @Flag(name: .long, help: "Clear the default model.")
        var clearModel: Bool = false

        @Option(
            name: .long,
            parsing: .upToNextOption,
            help: "Preferred skills list (names or UUIDs)."
        )
        var skills: [String] = []

        @Flag(name: .long, help: "Clear preferred skills list.")
        var clearSkills: Bool = false

        func validate() throws {
            if clearWorkspace, workspace != nil {
                throw ValidationError("Use either --workspace-path or --clear-workspace, not both.")
            }
            if clearModel, modelId != nil {
                throw ValidationError("Use either --model-id or --clear-model, not both.")
            }
            if clearSkills, !skills.isEmpty {
                throw ValidationError("Use either --skills or --clear-skills, not both.")
            }
        }

        func run() async throws {
            let store = CLIConfigStore()
            var config = store.loadOrDefault()

            if clearWorkspace {
                config.workspacePath = nil
            } else if let workspace {
                config.workspacePath = workspace
            }

            if clearModel {
                config.defaultModelId = nil
            } else if let modelId {
                guard let uuid = UUID(uuidString: modelId) else {
                    throw ValidationError("Invalid model UUID: \(modelId)")
                }
                config.defaultModelId = uuid
            }

            if clearSkills {
                config.preferredSkills = []
            } else if !skills.isEmpty {
                config.preferredSkills = skills
            }

            try store.save(config)

            let output = CLIOutput(
                writer: StdoutOutput(),
                format: resolvedGlobal.resolvedOutputFormat
            )
            let fallback = "Config updated."
            output.emit(config, fallback: fallback)
        }
    }

    struct Resolve: AsyncParsableCommand, GlobalOptionsAccessing {
        static let configuration = CommandConfiguration(
            abstract: "Show the resolved configuration with sources."
        )

        @OptionGroup
        var global: GlobalOptions

        @ParentCommand
        var parent: ConfigCommand

        var parentGlobal: GlobalOptions? { parent.resolvedGlobal }

        func run() async throws {
            let resolver = CLIConfigResolver()
            let resolved = resolver.resolve(options: resolvedGlobal)
            let output = CLIOutput(
                writer: StdoutOutput(),
                format: resolvedGlobal.resolvedOutputFormat
            )
            let skills = resolved.preferredSkills.value.joined(separator: ", ")
            let fallback = [
                "configPath=\(resolved.configPath.value)",
                "workspace=\(resolved.workspacePath.value ?? "-")",
                "model=\(resolved.defaultModelId.value?.uuidString ?? "-")",
                "skills=\(skills)",
                "format=\(resolved.outputFormat.value.rawValue)",
                "toolAccess=\(resolved.toolAccess.value.rawValue)",
                "store=\(resolved.store.value ?? "-")",
                "verbose=\(resolved.verbose.value)"
            ].joined(separator: " ")
            output.emit(resolved, fallback: fallback)
        }
    }

    struct Reset: AsyncParsableCommand, GlobalOptionsAccessing {
        static let configuration = CommandConfiguration(
            abstract: "Reset CLI configuration."
        )

        @OptionGroup
        var global: GlobalOptions

        @ParentCommand
        var parent: ConfigCommand

        var parentGlobal: GlobalOptions? { parent.resolvedGlobal }

        func run() async throws {
            let store = CLIConfigStore()
            try store.reset()
            let output = CLIOutput(
                writer: StdoutOutput(),
                format: resolvedGlobal.resolvedOutputFormat
            )
            output.emit("Config reset.")
        }
    }
}
