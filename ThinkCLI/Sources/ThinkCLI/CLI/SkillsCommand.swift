import ArgumentParser
import Database
import Foundation

struct SkillsCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Manage skills.",
        subcommands: [List.self, Enable.self, Disable.self]
    )

    @OptionGroup
    var global: GlobalOptions
}

extension SkillsCommand {
    struct List: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            abstract: "List skills."
        )

        @OptionGroup
        var global: GlobalOptions

        func run() async throws {
            let runtime = try CLIRuntimeProvider.runtime(for: global)
            let skills = try await runtime.database.read(SkillCommands.GetAll())
            let summaries = skills.map(SkillSummary.init(skill:))
            let fallback = summaries.isEmpty
                ? "No skills."
                : summaries.map { "\($0.id.uuidString)  \($0.name)" }.joined(separator: "\n")
            runtime.output.emit(summaries, fallback: fallback)
        }
    }

    struct Enable: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            abstract: "Enable a skill."
        )

        @OptionGroup
        var global: GlobalOptions

        @Argument(help: "Skill UUID.")
        var id: String

        func run() async throws {
            let runtime = try CLIRuntimeProvider.runtime(for: global)
            let skillId = try CLIParsing.parseUUID(id, field: "skill")
            _ = try await runtime.database.write(
                SkillCommands.SetEnabled(skillId: skillId, isEnabled: true)
            )
            runtime.output.emit("Enabled skill \(skillId.uuidString)")
        }
    }

    struct Disable: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            abstract: "Disable a skill."
        )

        @OptionGroup
        var global: GlobalOptions

        @Argument(help: "Skill UUID.")
        var id: String

        func run() async throws {
            let runtime = try CLIRuntimeProvider.runtime(for: global)
            let skillId = try CLIParsing.parseUUID(id, field: "skill")
            _ = try await runtime.database.write(
                SkillCommands.SetEnabled(skillId: skillId, isEnabled: false)
            )
            runtime.output.emit("Disabled skill \(skillId.uuidString)")
        }
    }
}
