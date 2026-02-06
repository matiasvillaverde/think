import ArgumentParser
import Database
import Foundation

struct StatusCommand: AsyncParsableCommand, GlobalOptionsAccessing {
    static let configuration = CommandConfiguration(
        commandName: "status",
        abstract: "Show CLI status."
    )

    @OptionGroup
    var global: GlobalOptions

    @ParentCommand
    var parent: ThinkCLI

    var parentGlobal: GlobalOptions? { parent.global }

    func run() async throws {
        let runtime = try await CLIRuntimeProvider.runtime(for: resolvedGlobal)
        let configStore = CLIConfigStore()
        let config = configStore.loadOrDefault()
        let resolvedWorkspace = resolvedGlobal.workspace ?? config.workspacePath
        let storeURL = AppStoreLocator.sharedStoreURL(
            bundleId: AppStoreLocator.defaultBundleId,
            overridePath: resolvedGlobal.store
        )

        let counts = try await Self.fetchCounts(runtime: runtime)
        let nodeRunning = await runtime.nodeMode.status()

        let report = CLIStatusReport(
            storePath: storeURL.path,
            workspacePath: resolvedWorkspace,
            modelsCount: counts.models,
            chatsCount: counts.chats,
            enabledSkillsCount: counts.enabledSkills,
            gatewayRunning: nodeRunning
        )

        let gatewayStatus = report.gatewayRunning ? "running" : "stopped"
        let fallback = [
            "store=\(report.storePath)",
            "models=\(report.modelsCount)",
            "chats=\(report.chatsCount)",
            "skills=\(report.enabledSkillsCount)",
            "gateway=\(gatewayStatus)"
        ].joined(separator: " ")
        runtime.output.emit(report, fallback: fallback)
    }
    @MainActor
    private static func fetchCounts(runtime: CLIRuntime) async throws -> (
        models: Int,
        chats: Int,
        enabledSkills: Int
    ) {
        let models = try await runtime.database.read(ModelCommands.FetchAll())
        let chats = try await runtime.database.read(ChatCommands.FetchGatewaySessions())
        let skills = try await runtime.database.read(SkillCommands.GetAll())
        let enabledSkills = skills.filter { $0.isEnabled }
        return (models.count, chats.count, enabledSkills.count)
    }

}

private struct CLIStatusReport: Codable, Sendable {
    let storePath: String
    let workspacePath: String?
    let modelsCount: Int
    let chatsCount: Int
    let enabledSkillsCount: Int
    let gatewayRunning: Bool
}
