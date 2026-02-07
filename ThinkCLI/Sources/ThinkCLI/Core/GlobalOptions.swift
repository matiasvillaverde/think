import ArgumentParser
import Foundation

struct GlobalOptions: ParsableArguments {
    @Flag(name: .long, help: "Output JSON instead of human-readable text.")
    var json: Bool = false

    @Option(
        name: .customLong("format"),
        help: "Output format (text, json, json-lines)."
    )
    var format: CLIOutputFormat?

    @Option(name: .long, help: "Override the SwiftData store name.")
    var store: String?

    @Option(name: .long, help: "Workspace root for SKILL.md and workspace tools.")
    var workspace: String?

    @Option(
        name: .customLong("tool-access"),
        help: "Tool execution policy (allow, deny)."
    )
    var toolAccess: CLIToolAccess?

    @Flag(name: .long, help: "Enable verbose logging.")
    var verbose: Bool = false

    var resolvedOutputFormat: CLIOutputFormat {
        format ?? (json ? .json : .text)
    }

    var resolvedToolAccess: CLIToolAccess {
        toolAccess ?? .allow
    }

    private static func resolved(
        json: Bool,
        format: CLIOutputFormat?,
        store: String?,
        workspace: String?,
        toolAccess: CLIToolAccess?,
        verbose: Bool
    ) -> GlobalOptions {
        var options = GlobalOptions()
        options.json = json
        options.format = format
        options.store = store
        options.workspace = workspace
        options.toolAccess = toolAccess
        options.verbose = verbose
        return options
    }

    func merged(with parent: GlobalOptions?) -> GlobalOptions {
        guard let parent else {
            return self
        }
        return Self.resolved(
            json: json || parent.json,
            format: format ?? parent.format,
            store: store ?? parent.store,
            workspace: workspace ?? parent.workspace,
            toolAccess: toolAccess ?? parent.toolAccess,
            verbose: verbose || parent.verbose
        )
    }
}
