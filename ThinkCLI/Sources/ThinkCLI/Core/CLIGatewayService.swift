import Foundation
import ViewModels

enum CLIGatewayService {
    struct Status: Codable, Sendable {
        let running: Bool
    }

    static func start(
        runtime: CLIRuntime,
        port: UInt16,
        token: String?,
        once: Bool
    ) async throws {
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

    static func status(runtime: CLIRuntime) async throws {
        let running = await runtime.nodeMode.status()
        let fallback = running ? "running" : "stopped"
        runtime.output.emit(Status(running: running), fallback: fallback)
    }
}
