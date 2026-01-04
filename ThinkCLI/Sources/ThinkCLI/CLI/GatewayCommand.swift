import ArgumentParser
import Foundation
import ViewModels

struct GatewayCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Manage the local gateway (node mode) server.",
        subcommands: [Start.self, Status.self]
    )

    @OptionGroup
    var global: GlobalOptions
}

extension GatewayCommand {
    struct Start: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            abstract: "Start the local gateway server."
        )

        @OptionGroup
        var global: GlobalOptions

        @Option(name: .long, help: "Port to bind the node server on.")
        var port: UInt16 = 9_876

        @Option(name: .long, help: "Optional bearer token for authorization.")
        var token: String?

        @Flag(name: .long, help: "Start and immediately stop (useful for tests).")
        var once: Bool = false

        func run() async throws {
            let runtime = try CLIRuntimeProvider.runtime(for: global)
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

    struct Status: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            abstract: "Check gateway server status."
        )

        @OptionGroup
        var global: GlobalOptions

        func run() async throws {
            let runtime = try CLIRuntimeProvider.runtime(for: global)
            let running = await runtime.nodeMode.status()
            let fallback = running ? "running" : "stopped"
            runtime.output.emit(GatewayStatus(running: running), fallback: fallback)
        }
    }
}

private struct GatewayStatus: Codable, Sendable {
    let running: Bool
}
