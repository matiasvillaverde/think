import ArgumentParser
import Foundation

struct OpenClawCommand: AsyncParsableCommand, GlobalOptionsAccessing {
    static let configuration = CommandConfiguration(
        commandName: "openclaw",
        abstract: "Manage remote OpenClaw gateway instances.",
        subcommands: [List.self, Upsert.self, Use.self, Delete.self, Test.self, ApprovePairing.self]
    )

    @OptionGroup
    var global: GlobalOptions

    @ParentCommand
    var parent: ThinkCLI

    var parentGlobal: GlobalOptions? { parent.global }
}

extension OpenClawCommand {
    struct List: AsyncParsableCommand, GlobalOptionsAccessing {
        static let configuration = CommandConfiguration(
            abstract: "List configured OpenClaw instances."
        )

        @OptionGroup
        var global: GlobalOptions

        @ParentCommand
        var parent: OpenClawCommand

        var parentGlobal: GlobalOptions? { parent.resolvedGlobal }

        func run() async throws {
            let runtime = try await CLIRuntimeProvider.runtime(for: resolvedGlobal)
            try await CLIOpenClawService.list(runtime: runtime)
        }
    }

    struct Upsert: AsyncParsableCommand, GlobalOptionsAccessing {
        static let configuration = CommandConfiguration(
            commandName: "upsert",
            abstract: "Create or update an OpenClaw instance."
        )

        @OptionGroup
        var global: GlobalOptions

        @ParentCommand
        var parent: OpenClawCommand

        var parentGlobal: GlobalOptions? { parent.resolvedGlobal }

        @Option(name: .long, help: "Optional instance UUID to update.")
        var id: String?

        @Option(name: .long, help: "Display name for the instance.")
        var name: String

        @Option(name: .long, help: "Gateway WebSocket URL (ws:// or wss://).")
        var url: String

        @Option(
            name: .long,
            help: "Optional shared gateway token. Stored in Keychain (not in the database)."
        )
        var token: String?

        @Flag(name: .long, help: "Mark this instance as active.")
        var activate: Bool = false

        func run() async throws {
            let runtime = try await CLIRuntimeProvider.runtime(for: resolvedGlobal)
            let instanceId: UUID? = try id.map { try CLIParsing.parseUUID($0, field: "id") }
            try await CLIOpenClawService.upsert(
                runtime: runtime,
                id: instanceId,
                name: name,
                urlString: url,
                token: token,
                activate: activate
            )
        }
    }

    struct Use: AsyncParsableCommand, GlobalOptionsAccessing {
        static let configuration = CommandConfiguration(
            abstract: "Set the active OpenClaw instance."
        )

        @OptionGroup
        var global: GlobalOptions

        @ParentCommand
        var parent: OpenClawCommand

        var parentGlobal: GlobalOptions? { parent.resolvedGlobal }

        @Option(name: .long, help: "Instance UUID. Omit to clear active instance.")
        var id: String?

        func run() async throws {
            let runtime = try await CLIRuntimeProvider.runtime(for: resolvedGlobal)
            let instanceId: UUID? = try id.map { try CLIParsing.parseUUID($0, field: "id") }
            try await CLIOpenClawService.use(runtime: runtime, id: instanceId)
        }
    }

    struct Delete: AsyncParsableCommand, GlobalOptionsAccessing {
        static let configuration = CommandConfiguration(
            abstract: "Delete an OpenClaw instance."
        )

        @OptionGroup
        var global: GlobalOptions

        @ParentCommand
        var parent: OpenClawCommand

        var parentGlobal: GlobalOptions? { parent.resolvedGlobal }

        @Option(name: .long, help: "Instance UUID to delete.")
        var id: String

        func run() async throws {
            let runtime = try await CLIRuntimeProvider.runtime(for: resolvedGlobal)
            let instanceId = try CLIParsing.parseUUID(id, field: "id")
            try await CLIOpenClawService.delete(runtime: runtime, id: instanceId)
        }
    }

    struct Test: AsyncParsableCommand, GlobalOptionsAccessing {
        static let configuration = CommandConfiguration(
            abstract: "Test connectivity for an OpenClaw instance."
        )

        @OptionGroup
        var global: GlobalOptions

        @ParentCommand
        var parent: OpenClawCommand

        var parentGlobal: GlobalOptions? { parent.resolvedGlobal }

        @Option(name: .long, help: "Instance UUID to test.")
        var id: String

        func run() async throws {
            let runtime = try await CLIRuntimeProvider.runtime(for: resolvedGlobal)
            let instanceId = try CLIParsing.parseUUID(id, field: "id")
            try await CLIOpenClawService.test(runtime: runtime, id: instanceId)
        }
    }

    struct ApprovePairing: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "approve-pairing",
            abstract: "Approve a pairing request on a gateway (requires shared token)."
        )

        @Option(name: .long, help: "Gateway WebSocket URL (ws:// or wss://).")
        var url: String

        @Option(name: .long, help: "Shared gateway token.")
        var token: String

        @Option(name: .long, help: "Pairing requestId from a 'pairing required' response.")
        var requestId: String

        func run() async throws {
            try await CLIOpenClawService.approvePairing(
                urlString: url,
                token: token,
                requestId: requestId
            )
        }
    }
}
