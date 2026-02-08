import Abstractions
import Database
import Foundation
import Testing
@testable import ThinkCLI

@Suite("OpenClaw Remote Acceptance Tests", .serialized)
struct OpenClawRemoteAcceptanceTests {
    @Test("ThinkCLI can pair and connect to a real OpenClaw gateway (opt-in)")
    func pairsAndConnectsToRealGateway() async throws {
        let env: [String: String] = ProcessInfo.processInfo.environment
        guard env["OPENCLAW_ACCEPTANCE"] == "1" else {
            return
        }

        guard let wsURL: String = env["OPENCLAW_TEST_WS_URL"], !wsURL.isEmpty else {
            return
        }
        guard let token: String = env["OPENCLAW_TEST_TOKEN"], !token.isEmpty else {
            return
        }

        let context = try await TestRuntime.make()

        try await withRuntime(context.runtime) {
            var instanceId: UUID?

            do {
                try await runCLI([
                    "openclaw", "upsert",
                    "--name", "Acceptance Gateway",
                    "--url", wsURL,
                    "--token", token,
                    "--activate"
                ])

                let instances: [OpenClawInstanceRecord] = try await context.database.read(
                    SettingsCommands.FetchOpenClawInstances()
                )
                #expect(instances.count == 1)
                instanceId = instances.first?.id

                guard let id: UUID = instanceId else {
                    Issue.record("Expected an OpenClaw instance id to be created.")
                    return
                }

                let requestId: String = try await runAndExtractPairingRequestId(
                    context: context,
                    instanceId: id
                )

                try await runCLI([
                    "openclaw", "approve-pairing",
                    "--url", wsURL,
                    "--token", token,
                    "--request-id", requestId
                ])

                let connectedLines: [String] = try await runAndCaptureLines(context: context) {
                    try await runCLI(["openclaw", "test", "--id", id.uuidString])
                }
                #expect(connectedLines.contains { $0.contains("Connected.") })

                try await runCLI(["openclaw", "delete", "--id", id.uuidString])
            } catch {
                if let id = instanceId {
                    try? await runCLI(["openclaw", "delete", "--id", id.uuidString])
                }
                throw error
            }
        }
    }

    // MARK: - Helpers

    @MainActor
    private func runAndCaptureLines(
        context: TestRuntime,
        operation: () async throws -> Void
    ) async throws -> [String] {
        let start: Int = context.output.lines.count
        try await operation()
        return Array(context.output.lines.dropFirst(start))
    }

    @MainActor
    private func runAndExtractPairingRequestId(
        context: TestRuntime,
        instanceId: UUID
    ) async throws -> String {
        let lines: [String] = try await runAndCaptureLines(context: context) {
            try await runCLI(["openclaw", "test", "--id", instanceId.uuidString])
        }

        #expect(lines.contains { $0.contains("Pairing required.") })

        if let requestId: String = extractRequestId(lines: lines) {
            return requestId
        }

        Issue.record(
            """
            Expected a pairing requestId from `think openclaw test`.
            Output:
            \(lines.joined(separator: "\n"))
            """
        )
        throw AcceptanceError.missingPairingRequestId
    }

    private func extractRequestId(lines: [String]) -> String? {
        // Line format: "Pairing required. requestId=<uuid>"
        for line in lines {
            guard let range = line.range(of: "requestId=") else {
                continue
            }
            let tail = line[range.upperBound...]
            let candidate = tail.trimmingCharacters(in: .whitespacesAndNewlines)
            if UUID(uuidString: candidate) != nil {
                return candidate
            }
        }
        return nil
    }
}

private enum AcceptanceError: Error, Sendable {
    case missingPairingRequestId
}
