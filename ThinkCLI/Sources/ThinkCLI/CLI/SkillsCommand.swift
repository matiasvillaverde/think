import ArgumentParser
import Foundation

struct SkillsCommand: AsyncParsableCommand, GlobalOptionsAccessing {
    static let configuration = CommandConfiguration(
        commandName: "skills",
        abstract: "Manage skills.",
        subcommands: [List.self, Create.self, Enable.self, Disable.self]
    )

    @OptionGroup
    var global: GlobalOptions

    @ParentCommand
    var parent: ThinkCLI

    var parentGlobal: GlobalOptions? { parent.global }
}

extension SkillsCommand {
    struct List: AsyncParsableCommand, GlobalOptionsAccessing {
        static let configuration = CommandConfiguration(
            abstract: "List skills."
        )

        @OptionGroup
        var global: GlobalOptions

        @ParentCommand
        var parent: SkillsCommand

        var parentGlobal: GlobalOptions? { parent.resolvedGlobal }

        @MainActor
        func run() async throws {
            let runtime = try await CLIRuntimeProvider.runtime(for: resolvedGlobal)
            try await CLISkillsService.list(runtime: runtime)
        }
    }

    struct Create: AsyncParsableCommand, GlobalOptionsAccessing {
        static let configuration = CommandConfiguration(
            abstract: "Create a skill."
        )

        @OptionGroup
        var global: GlobalOptions

        @ParentCommand
        var parent: SkillsCommand

        var parentGlobal: GlobalOptions? { parent.resolvedGlobal }

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
            let runtime = try await CLIRuntimeProvider.runtime(for: resolvedGlobal)
            let chatId = try chat.map { try CLIParsing.parseUUID($0, field: "chat") }
            try await CLISkillsService.create(
                runtime: runtime,
                name: name,
                description: description,
                instructions: instructions,
                tools: tools,
                chatId: chatId,
                disabled: disabled
            )
        }
    }

    struct Enable: AsyncParsableCommand, GlobalOptionsAccessing {
        static let configuration = CommandConfiguration(
            abstract: "Enable a skill."
        )

        @OptionGroup
        var global: GlobalOptions

        @ParentCommand
        var parent: SkillsCommand

        var parentGlobal: GlobalOptions? { parent.resolvedGlobal }

        @Argument(help: "Skill UUID.")
        var id: String

        func run() async throws {
            let runtime = try await CLIRuntimeProvider.runtime(for: resolvedGlobal)
            let skillId = try CLIParsing.parseUUID(id, field: "skill")
            try await CLISkillsService.enable(runtime: runtime, skillId: skillId)
        }
    }

    struct Disable: AsyncParsableCommand, GlobalOptionsAccessing {
        static let configuration = CommandConfiguration(
            abstract: "Disable a skill."
        )

        @OptionGroup
        var global: GlobalOptions

        @ParentCommand
        var parent: SkillsCommand

        var parentGlobal: GlobalOptions? { parent.resolvedGlobal }

        @Argument(help: "Skill UUID.")
        var id: String

        func run() async throws {
            let runtime = try await CLIRuntimeProvider.runtime(for: resolvedGlobal)
            let skillId = try CLIParsing.parseUUID(id, field: "skill")
            try await CLISkillsService.disable(runtime: runtime, skillId: skillId)
        }
    }
}
