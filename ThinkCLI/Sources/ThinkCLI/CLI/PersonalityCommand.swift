import ArgumentParser
import Foundation

struct PersonalityCommand: AsyncParsableCommand, GlobalOptionsAccessing {
    static let configuration = CommandConfiguration(
        commandName: "personality",
        abstract: "Manage personalities.",
        subcommands: [List.self, Create.self, Update.self, Delete.self, Chat.self]
    )

    @OptionGroup
    var global: GlobalOptions

    @ParentCommand
    var parent: ThinkCLI

    var parentGlobal: GlobalOptions? { parent.global }
}

extension PersonalityCommand {
    struct List: AsyncParsableCommand, GlobalOptionsAccessing {
        static let configuration = CommandConfiguration(
            abstract: "List personalities."
        )

        @OptionGroup
        var global: GlobalOptions

        @ParentCommand
        var parent: PersonalityCommand

        var parentGlobal: GlobalOptions? { parent.resolvedGlobal }

        @MainActor
        func run() async throws {
            let runtime = try await CLIRuntimeProvider.runtime(for: resolvedGlobal)
            try await CLIPersonalityService.list(runtime: runtime)
        }
    }

    struct Create: AsyncParsableCommand, GlobalOptionsAccessing {
        private static let categoryHelp = ArgumentHelp(
            "Category (creative, education, entertainment, health, lifestyle, personal, " +
            "productivity)."
        )

        static let configuration = CommandConfiguration(
            abstract: "Create a custom personality."
        )

        @OptionGroup
        var global: GlobalOptions

        @ParentCommand
        var parent: PersonalityCommand

        var parentGlobal: GlobalOptions? { parent.resolvedGlobal }

        @Option(name: .long, help: "Personality name.")
        var name: String

        @Option(name: .long, help: "Personality description.")
        var description: String

        @Option(name: .long, help: "System instructions for the personality.")
        var instructions: String

        @Option(
            name: .long,
            help: Self.categoryHelp
        )
        var category: String?

        func run() async throws {
            let runtime = try await CLIRuntimeProvider.runtime(for: resolvedGlobal)
            let categoryValue = try category
                .map(CLIParsing.parsePersonalityCategory(_:)) ?? .productivity
            try await CLIPersonalityService.create(
                runtime: runtime,
                name: name,
                description: description,
                instructions: instructions,
                category: categoryValue
            )
        }
    }

    struct Update: AsyncParsableCommand, GlobalOptionsAccessing {
        private static let categoryHelp = ArgumentHelp(
            "New category (creative, education, entertainment, health, lifestyle, personal, " +
            "productivity)."
        )

        static let configuration = CommandConfiguration(
            abstract: "Update a personality."
        )

        @OptionGroup
        var global: GlobalOptions

        @ParentCommand
        var parent: PersonalityCommand

        var parentGlobal: GlobalOptions? { parent.resolvedGlobal }

        @Argument(help: "Personality UUID.")
        var id: String

        @Option(name: .long, help: "New personality name.")
        var name: String?

        @Option(name: .long, help: "New personality description.")
        var description: String?

        @Option(name: .long, help: "New system instructions.")
        var instructions: String?

        @Option(
            name: .long,
            help: Self.categoryHelp
        )
        var category: String?

        func run() async throws {
            guard name != nil || description != nil || instructions != nil || category != nil else {
                throw ValidationError("Provide at least one field to update.")
            }
            let runtime = try await CLIRuntimeProvider.runtime(for: resolvedGlobal)
            let personalityId = try CLIParsing.parseUUID(id, field: "personality")
            let categoryValue = try category.map(CLIParsing.parsePersonalityCategory(_:))
            try await CLIPersonalityService.update(
                runtime: runtime,
                personalityId: personalityId,
                name: name,
                description: description,
                instructions: instructions,
                category: categoryValue
            )
        }
    }

    struct Delete: AsyncParsableCommand, GlobalOptionsAccessing {
        static let configuration = CommandConfiguration(
            abstract: "Delete a custom personality."
        )

        @OptionGroup
        var global: GlobalOptions

        @ParentCommand
        var parent: PersonalityCommand

        var parentGlobal: GlobalOptions? { parent.resolvedGlobal }

        @Argument(help: "Personality UUID.")
        var id: String

        func run() async throws {
            let runtime = try await CLIRuntimeProvider.runtime(for: resolvedGlobal)
            let personalityId = try CLIParsing.parseUUID(id, field: "personality")
            try await CLIPersonalityService.delete(runtime: runtime, personalityId: personalityId)
        }
    }

    struct Chat: AsyncParsableCommand, GlobalOptionsAccessing {
        static let configuration = CommandConfiguration(
            abstract: "Get or create the chat for a personality."
        )

        @OptionGroup
        var global: GlobalOptions

        @ParentCommand
        var parent: PersonalityCommand

        var parentGlobal: GlobalOptions? { parent.resolvedGlobal }

        @Argument(help: "Personality UUID.")
        var id: String

        func run() async throws {
            let runtime = try await CLIRuntimeProvider.runtime(for: resolvedGlobal)
            let personalityId = try CLIParsing.parseUUID(id, field: "personality")
            try await CLIPersonalityService.chat(runtime: runtime, personalityId: personalityId)
        }
    }
}
