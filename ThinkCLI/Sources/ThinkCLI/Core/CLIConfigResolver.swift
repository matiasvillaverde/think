import Foundation

enum CLISettingSource: String, Codable, Sendable {
    case cli
    case configFile
    case environment
    case defaultValue
}

struct CLIResolvedSetting<Value: Codable & Equatable & Sendable>: Codable, Equatable, Sendable {
    let value: Value
    let source: CLISettingSource
}

struct CLIResolvedConfig: Codable, Equatable, Sendable {
    let configPath: CLIResolvedSetting<String>
    let workspacePath: CLIResolvedSetting<String?>
    let defaultModelId: CLIResolvedSetting<UUID?>
    let preferredSkills: CLIResolvedSetting<[String]>
    let outputFormat: CLIResolvedSetting<CLIOutputFormat>
    let toolAccess: CLIResolvedSetting<CLIToolAccess>
    let store: CLIResolvedSetting<String?>
    let verbose: CLIResolvedSetting<Bool>
}

struct CLIConfigResolver {
    let configStore: CLIConfigStore
    let environment: [String: String]

    init(
        configStore: CLIConfigStore = CLIConfigStore(),
        environment: [String: String] = ProcessInfo.processInfo.environment
    ) {
        self.configStore = configStore
        self.environment = environment
    }

    func resolve(options: GlobalOptions) -> CLIResolvedConfig {
        let config = configStore.loadOrDefault()

        let configPathSource: CLISettingSource
        if let override = environment[CLIConfigStore.overrideEnvKey], !override.isEmpty {
            configPathSource = .environment
        } else {
            configPathSource = .defaultValue
        }

        let workspace: CLIResolvedSetting<String?>
        if let workspacePath = options.workspace {
            workspace = CLIResolvedSetting(value: workspacePath, source: .cli)
        } else if let workspacePath = config.workspacePath {
            workspace = CLIResolvedSetting(value: workspacePath, source: .configFile)
        } else {
            workspace = CLIResolvedSetting(value: nil, source: .defaultValue)
        }

        let defaultModelId: CLIResolvedSetting<UUID?>
        if let modelId = config.defaultModelId {
            defaultModelId = CLIResolvedSetting(value: modelId, source: .configFile)
        } else {
            defaultModelId = CLIResolvedSetting(value: nil, source: .defaultValue)
        }

        let preferredSkills: CLIResolvedSetting<[String]>
        if !config.preferredSkills.isEmpty {
            preferredSkills = CLIResolvedSetting(value: config.preferredSkills, source: .configFile)
        } else {
            preferredSkills = CLIResolvedSetting(value: [], source: .defaultValue)
        }

        let outputFormat: CLIResolvedSetting<CLIOutputFormat>
        if options.format != nil || options.json {
            outputFormat = CLIResolvedSetting(value: options.resolvedOutputFormat, source: .cli)
        } else {
            outputFormat = CLIResolvedSetting(value: .text, source: .defaultValue)
        }

        let toolAccess: CLIResolvedSetting<CLIToolAccess>
        if let toolAccessValue = options.toolAccess {
            toolAccess = CLIResolvedSetting(value: toolAccessValue, source: .cli)
        } else {
            toolAccess = CLIResolvedSetting(value: .allow, source: .defaultValue)
        }

        let store: CLIResolvedSetting<String?>
        if let storeValue = options.store {
            store = CLIResolvedSetting(value: storeValue, source: .cli)
        } else {
            store = CLIResolvedSetting(value: nil, source: .defaultValue)
        }

        let verbose: CLIResolvedSetting<Bool>
        if options.verbose {
            verbose = CLIResolvedSetting(value: true, source: .cli)
        } else {
            verbose = CLIResolvedSetting(value: false, source: .defaultValue)
        }

        return CLIResolvedConfig(
            configPath: CLIResolvedSetting(
                value: configStore.url.path,
                source: configPathSource
            ),
            workspacePath: workspace,
            defaultModelId: defaultModelId,
            preferredSkills: preferredSkills,
            outputFormat: outputFormat,
            toolAccess: toolAccess,
            store: store,
            verbose: verbose
        )
    }
}
