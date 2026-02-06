import ArgumentParser
import Foundation

struct DoctorCommand: AsyncParsableCommand, GlobalOptionsAccessing {
    static let configuration = CommandConfiguration(
        commandName: "doctor",
        abstract: "Run diagnostics checks."
    )

    @OptionGroup
    var global: GlobalOptions

    @ParentCommand
    var parent: ThinkCLI

    var parentGlobal: GlobalOptions? { parent.global }

    func run() async throws {
        let runtime = try await CLIRuntimeProvider.runtime(for: resolvedGlobal)
        let diagnostics = CLIDiagnostics()
        let report = await diagnostics.run(runtime: runtime, options: resolvedGlobal)
        let fallback = report.checks.map { check in
            "[\(check.status.rawValue.uppercased())] \(check.name): \(check.message)"
        }.joined(separator: "\n")
        runtime.output.emit(report, fallback: fallback)
    }
}
