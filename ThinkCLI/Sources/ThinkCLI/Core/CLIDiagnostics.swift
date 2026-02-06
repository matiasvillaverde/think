import Abstractions
import Database
import Foundation

struct CLIDiagnostics {
    struct Check: Codable, Equatable, Sendable {
        enum Status: String, Codable, Sendable {
            case ok
            case warning
            case failed
        }

        let name: String
        let status: Status
        let message: String
    }

    struct Report: Codable, Equatable, Sendable {
        let checks: [Check]
    }

    let configStore: CLIConfigStore
    let fileManager: FileManager
    let metallibChecker: () -> Bool

    init(
        configStore: CLIConfigStore = CLIConfigStore(),
        fileManager: FileManager = .default,
        metallibChecker: @escaping () -> Bool = {
            CLIMetalLibraryBootstrapper.ensureMetallibAvailable()
        }
    ) {
        self.configStore = configStore
        self.fileManager = fileManager
        self.metallibChecker = metallibChecker
    }

    func run(runtime: CLIRuntime, options: GlobalOptions) async -> Report {
        var checks: [Check] = []

        let configResult: Result<CLIConfig, Error>
        if configStore.exists() {
            do {
                let config = try configStore.load()
                configResult = .success(config)
            } catch {
                configResult = .failure(error)
            }
        } else {
            configResult = .success(CLIConfig())
        }

        switch configResult {
        case .success:
            let status: Check.Status = configStore.exists() ? .ok : .warning
            let message = configStore.exists()
                ? "Config file loaded."
                : "No config file found."
            checks.append(Check(name: "config", status: status, message: message))
        case .failure(let error):
            checks.append(
                Check(
                    name: "config",
                    status: .failed,
                    message: "Config read failed: \(error.localizedDescription)"
                )
            )
        }

        let config = configStore.loadOrDefault()
        let resolvedWorkspace = options.workspace ?? config.workspacePath
        if let workspace = resolvedWorkspace, !workspace.isEmpty {
            var isDirectory: ObjCBool = false
            if fileManager.fileExists(atPath: workspace, isDirectory: &isDirectory),
               isDirectory.boolValue {
                checks.append(Check(name: "workspace", status: .ok, message: workspace))
            } else {
                checks.append(
                    Check(
                        name: "workspace",
                        status: .warning,
                        message: "Workspace not found: \(workspace)"
                    )
                )
            }
        } else {
            checks.append(
                Check(
                    name: "workspace",
                    status: .warning,
                    message: "No workspace configured."
                )
            )
        }

        let storeURL = AppStoreLocator.sharedStoreURL(
            bundleId: AppStoreLocator.defaultBundleId,
            overridePath: options.store
        )
        let storeDirectory = storeURL.deletingLastPathComponent()
        var storeIsDirectory: ObjCBool = false
        if fileManager.fileExists(atPath: storeDirectory.path, isDirectory: &storeIsDirectory),
           storeIsDirectory.boolValue,
           fileManager.isWritableFile(atPath: storeDirectory.path) {
            checks.append(
                Check(
                    name: "store",
                    status: .ok,
                    message: storeURL.path
                )
            )
        } else {
            checks.append(
                Check(
                    name: "store",
                    status: .warning,
                    message: "Store directory not writable: \(storeDirectory.path)"
                )
            )
        }

        let metallibAvailable = metallibChecker()
        checks.append(
            Check(
                name: "metallib",
                status: metallibAvailable ? .ok : .warning,
                message: metallibAvailable ? "MLX metallib available." : "MLX metallib missing."
            )
        )

        do {
            let modelCount = try await Self.fetchModelCount(runtime: runtime)
            checks.append(
                Check(
                    name: "database",
                    status: .ok,
                    message: "Database reachable."
                )
            )
            let modelStatus: Check.Status = modelCount == 0 ? .warning : .ok
            checks.append(
                Check(
                    name: "models",
                    status: modelStatus,
                    message: "Models available: \(modelCount)"
                )
            )
        } catch {
            checks.append(
                Check(
                    name: "database",
                    status: .failed,
                    message: "Database error: \(error.localizedDescription)"
                )
            )
        }

        do {
            let enabledCount = try await Self.fetchEnabledSkillCount(runtime: runtime)
            let status: Check.Status = enabledCount == 0 ? .warning : .ok
            checks.append(
                Check(
                    name: "skills",
                    status: status,
                    message: "Enabled skills: \(enabledCount)"
                )
            )
        } catch {
            checks.append(
                Check(
                    name: "skills",
                    status: .warning,
                    message: "Skills check failed: \(error.localizedDescription)"
                )
            )
        }

        await runtime.tooling.configureTool(identifiers: Set(ToolIdentifier.allCases))
        let definitions = await runtime.tooling.getAllToolDefinitions()
        let toolsStatus: Check.Status = definitions.isEmpty ? .warning : .ok
        checks.append(
            Check(
                name: "tools",
                status: toolsStatus,
                message: "Tools available: \(definitions.count)"
            )
        )

        let nodeRunning = await runtime.nodeMode.status()
        checks.append(
            Check(
                name: "gateway",
                status: .ok,
                message: nodeRunning ? "Gateway running." : "Gateway stopped."
            )
        )

        return Report(checks: checks)
    }
    @MainActor
    private static func fetchModelCount(runtime: CLIRuntime) async throws -> Int {
        let models = try await runtime.database.read(ModelCommands.FetchAll())
        return models.count
    }

    @MainActor
    private static func fetchEnabledSkillCount(runtime: CLIRuntime) async throws -> Int {
        let skills = try await runtime.database.read(SkillCommands.GetAll())
        return skills.filter { $0.isEnabled }.count
    }

}
