import ArgumentParser
import Foundation

struct GlobalOptions: ParsableArguments {
    @Flag(name: .long, help: "Output JSON instead of human-readable text.")
    var json: Bool = false

    @Option(name: .long, help: "Override the SwiftData store name.")
    var store: String?

    @Option(name: .long, help: "Workspace root for SKILL.md and workspace tools.")
    var workspace: String?

    @Flag(name: .long, help: "Enable verbose logging.")
    var verbose: Bool = false

    private static func resolved(
        json: Bool,
        store: String?,
        workspace: String?,
        verbose: Bool
    ) -> GlobalOptions {
        var options = GlobalOptions()
        options.json = json
        options.store = store
        options.workspace = workspace
        options.verbose = verbose
        return options
    }

    func merged(with parent: GlobalOptions?) -> GlobalOptions {
        guard let parent else {
            return self
        }
        return Self.resolved(
            json: json || parent.json,
            store: store ?? parent.store,
            workspace: workspace ?? parent.workspace,
            verbose: verbose || parent.verbose
        )
    }
}
