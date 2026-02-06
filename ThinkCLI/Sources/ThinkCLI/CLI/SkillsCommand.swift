import ArgumentParser
import Database
import Foundation

struct SkillsCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "skills",
        abstract: "Manage skills.",
        subcommands: [List.self, Create.self, Enable.self, Disable.self]
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

        @MainActor
        func run() async throws {
            let runtime = try await CLIRuntimeProvider.runtime(for: global)
            let skills = try await runtime.database.read(SkillCommands.GetAll())
            let summaries = skills.map(SkillSummary.init(skill:))
            let fallback = summaries.isEmpty
                ? "No skills."
                : summaries.map { "\($0.id.uuidString)  \($0.name)" }.joined(separator: "\n")
            runtime.output.emit(summaries, fallback: fallback)
        }
    }

    struct Create: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            abstract: "Create a skill."
        )

        @OptionGroup
        var global: GlobalOptions

        @Option(name: .long, help: "Skill name.")
        var name: String

        @Option(name: .long, help: "Skill description.")
        var description: String = ""

        @Option(name: .long, help: "Skill instructions.")
        var instructions: String = ""

        @Option(
            name: .long,
            parsing: .upToNextOption,
            help: "Tool names associated with the skill."
        )
        var tools: [String] = []

        @Option(name: .long, help: "Optional chat UUID.")
        var chat: String?

        @Flag(name: .long, help: "Create the skill disabled.")
        var disabled: Bool = false

        func run() async throws {
            let runtime = try await CLIRuntimeProvider.runtime(for: global)
            let chatId = try chat.map { try CLIParsing.parseUUID($0, field: "chat") }
            let skillId = try await runtime.database.write(
                SkillCommands.Create(
                    name: name,
                    skillDescription: description,
                    instructions: instructions,
                    tools: tools,
                    isSystem: false,
                    isEnabled: !disabled,
                    chatId: chatId
                )
            )
            runtime.output.emit("Created skill \(skillId.uuidString)")
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
            let runtime = try await CLIRuntimeProvider.runtime(for: global)
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
            let runtime = try await CLIRuntimeProvider.runtime(for: global)
            let skillId = try CLIParsing.parseUUID(id, field: "skill")
            _ = try await runtime.database.write(
                SkillCommands.SetEnabled(skillId: skillId, isEnabled: false)
            )
            runtime.output.emit("Disabled skill \(skillId.uuidString)")
        }
    }
}
