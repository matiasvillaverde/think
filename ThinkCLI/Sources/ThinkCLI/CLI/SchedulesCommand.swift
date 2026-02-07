import ArgumentParser
import Foundation

struct SchedulesCommand: AsyncParsableCommand, GlobalOptionsAccessing {
    static let configuration = CommandConfiguration(
        commandName: "schedules",
        abstract: "Manage automation schedules.",
        subcommands: [List.self, Create.self, Update.self, Enable.self, Disable.self, Delete.self]
    )

    @OptionGroup
    var global: GlobalOptions

    @ParentCommand
    var parent: ThinkCLI

    var parentGlobal: GlobalOptions? { parent.global }
}

extension SchedulesCommand {
    struct List: AsyncParsableCommand, GlobalOptionsAccessing {
        static let configuration = CommandConfiguration(
            abstract: "List schedules."
        )

        @OptionGroup
        var global: GlobalOptions

        @ParentCommand
        var parent: SchedulesCommand

        var parentGlobal: GlobalOptions? { parent.resolvedGlobal }

        @Option(name: .long, help: "Filter schedules by chat UUID.")
        var chat: String?

        @MainActor
        func run() async throws {
            let runtime = try await CLIRuntimeProvider.runtime(for: resolvedGlobal)
            let chatId = try chat.map { try CLIParsing.parseUUID($0, field: "chat") }
            try await CLISchedulesService.list(runtime: runtime, chatId: chatId)
        }
    }

    struct Create: AsyncParsableCommand, GlobalOptionsAccessing {
        static let configuration = CommandConfiguration(
            abstract: "Create a schedule."
        )

        @OptionGroup
        var global: GlobalOptions

        @ParentCommand
        var parent: SchedulesCommand

        var parentGlobal: GlobalOptions? { parent.resolvedGlobal }

        @Option(name: .long, help: "Schedule title.")
        var title: String

        @Option(name: .long, help: "Prompt to run.")
        var prompt: String

        @Option(name: .long, help: "Cron expression or one-shot ISO date.")
        var cron: String

        @Option(name: .long, help: "Schedule kind: cron or one_shot.")
        var kind: String = "cron"

        @Option(name: .long, help: "Action type: text or image.")
        var action: String = "text"

        @Option(name: .long, help: "Timezone identifier.")
        var timezone: String?

        @Option(name: .long, parsing: .upToNextOption, help: "Tools to allow.")
        var tools: [String] = []

        @Option(name: .long, help: "Optional chat UUID.")
        var chat: String?

        @Flag(name: .long, help: "Create schedule disabled.")
        var disabled: Bool = false

        func run() async throws {
            let runtime = try await CLIRuntimeProvider.runtime(for: resolvedGlobal)
            let scheduleKind = try CLIParsing.parseScheduleKind(kind)
            let actionType = try CLIParsing.parseActionType(action)
            let toolIdentifiers = try CLIParsing.parseToolIdentifiers(tools)
            let toolNames = toolIdentifiers.map(\.toolName)
            let chatId = try chat.map { try CLIParsing.parseUUID($0, field: "chat") }

            try await CLISchedulesService.create(
                runtime: runtime,
                title: title,
                prompt: prompt,
                cronExpression: cron,
                scheduleKind: scheduleKind,
                actionType: actionType,
                timezoneIdentifier: timezone,
                toolNames: toolNames,
                isEnabled: !disabled,
                chatId: chatId
            )
        }
    }

    struct Update: AsyncParsableCommand, GlobalOptionsAccessing {
        static let configuration = CommandConfiguration(
            abstract: "Update a schedule."
        )

        @OptionGroup
        var global: GlobalOptions

        @ParentCommand
        var parent: SchedulesCommand

        var parentGlobal: GlobalOptions? { parent.resolvedGlobal }

        @Argument(help: "Schedule UUID.")
        var id: String

        @Option(name: .long, help: "Schedule title.")
        var title: String?

        @Option(name: .long, help: "Prompt to run.")
        var prompt: String?

        @Option(name: .long, help: "Cron expression or one-shot ISO date.")
        var cron: String?

        @Option(name: .long, help: "Schedule kind: cron or one_shot.")
        var kind: String?

        @Option(name: .long, help: "Action type: text or image.")
        var action: String?

        @Option(name: .long, help: "Timezone identifier.")
        var timezone: String?

        @Option(name: .long, parsing: .upToNextOption, help: "Tools to allow.")
        var tools: [String] = []

        func run() async throws {
            let runtime = try await CLIRuntimeProvider.runtime(for: resolvedGlobal)
            let scheduleId = try CLIParsing.parseUUID(id, field: "schedule")

            let kindValue = try kind.map(CLIParsing.parseScheduleKind(_:))
            let actionValue = try action.map(CLIParsing.parseActionType(_:))
            let toolNames: [String]?
            if tools.isEmpty {
                toolNames = nil
            } else {
                toolNames = try CLIParsing.parseToolIdentifiers(tools).map(\.toolName)
            }

            try await CLISchedulesService.update(
                runtime: runtime,
                scheduleId: scheduleId,
                title: title,
                prompt: prompt,
                cronExpression: cron,
                timezoneIdentifier: timezone,
                toolNames: toolNames,
                actionType: actionValue,
                scheduleKind: kindValue
            )
        }
    }

    struct Enable: AsyncParsableCommand, GlobalOptionsAccessing {
        static let configuration = CommandConfiguration(
            abstract: "Enable a schedule."
        )

        @OptionGroup
        var global: GlobalOptions

        @ParentCommand
        var parent: SchedulesCommand

        var parentGlobal: GlobalOptions? { parent.resolvedGlobal }

        @Argument(help: "Schedule UUID.")
        var id: String

        func run() async throws {
            let runtime = try await CLIRuntimeProvider.runtime(for: resolvedGlobal)
            let scheduleId = try CLIParsing.parseUUID(id, field: "schedule")
            try await CLISchedulesService.enable(runtime: runtime, scheduleId: scheduleId)
        }
    }

    struct Disable: AsyncParsableCommand, GlobalOptionsAccessing {
        static let configuration = CommandConfiguration(
            abstract: "Disable a schedule."
        )

        @OptionGroup
        var global: GlobalOptions

        @ParentCommand
        var parent: SchedulesCommand

        var parentGlobal: GlobalOptions? { parent.resolvedGlobal }

        @Argument(help: "Schedule UUID.")
        var id: String

        func run() async throws {
            let runtime = try await CLIRuntimeProvider.runtime(for: resolvedGlobal)
            let scheduleId = try CLIParsing.parseUUID(id, field: "schedule")
            try await CLISchedulesService.disable(runtime: runtime, scheduleId: scheduleId)
        }
    }

    struct Delete: AsyncParsableCommand, GlobalOptionsAccessing {
        static let configuration = CommandConfiguration(
            abstract: "Delete a schedule."
        )

        @OptionGroup
        var global: GlobalOptions

        @ParentCommand
        var parent: SchedulesCommand

        var parentGlobal: GlobalOptions? { parent.resolvedGlobal }

        @Argument(help: "Schedule UUID.")
        var id: String

        func run() async throws {
            let runtime = try await CLIRuntimeProvider.runtime(for: resolvedGlobal)
            let scheduleId = try CLIParsing.parseUUID(id, field: "schedule")
            try await CLISchedulesService.delete(runtime: runtime, scheduleId: scheduleId)
        }
    }
}
