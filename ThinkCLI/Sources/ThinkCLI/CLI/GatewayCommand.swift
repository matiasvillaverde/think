import ArgumentParser
import Foundation
import ViewModels

struct GatewayCommand: AsyncParsableCommand, GlobalOptionsAccessing {
    static let configuration = CommandConfiguration(
        commandName: "gateway",
        abstract: "Manage the local gateway (node mode) server.",
        subcommands: [Start.self, Status.self]
    )

    @OptionGroup
    var global: GlobalOptions

    @ParentCommand
    var parent: ThinkCLI

    var parentGlobal: GlobalOptions? { parent.global }
}

extension GatewayCommand {
    struct Start: AsyncParsableCommand, GlobalOptionsAccessing {
        static let configuration = CommandConfiguration(
            abstract: "Start the local gateway server."
        )

        @OptionGroup
        var global: GlobalOptions

        @ParentCommand
        var parent: GatewayCommand

        var parentGlobal: GlobalOptions? { parent.resolvedGlobal }

        @Option(name: .long, help: "Port to bind the node server on.")
        var port: UInt16 = 9_876

        @Option(name: .long, help: "Optional bearer token for authorization.")
        var token: String?

        @Flag(name: .long, help: "Start and immediately stop (useful for tests).")
        var once: Bool = false

        func run() async throws {
            let runtime = try await CLIRuntimeProvider.runtime(for: resolvedGlobal)
            try await runtime.nodeMode.start(
                configuration: NodeModeConfiguration(
                    port: port,
                    authToken: token
                )
            )

            runtime.output.emit("Gateway server running on port \(port)")

            if once {
                await runtime.nodeMode.stop()
                runtime.output.emit("Gateway server stopped")
                return
            }

            do {
                try await Task.sleep(nanoseconds: UInt64.max)
            } catch {
                await runtime.nodeMode.stop()
            }
        }
    }

    struct Status: AsyncParsableCommand, GlobalOptionsAccessing {
        static let configuration = CommandConfiguration(
            abstract: "Check gateway server status."
        )

        @OptionGroup
        var global: GlobalOptions

        @ParentCommand
        var parent: GatewayCommand

        var parentGlobal: GlobalOptions? { parent.resolvedGlobal }

        func run() async throws {
            let runtime = try await CLIRuntimeProvider.runtime(for: resolvedGlobal)
            let running = await runtime.nodeMode.status()
            let fallback = running ? "running" : "stopped"
            runtime.output.emit(GatewayStatus(running: running), fallback: fallback)
        }
    }
}

private struct GatewayStatus: Codable, Sendable {
    let running: Bool
}
