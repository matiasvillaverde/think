import ArgumentParser
import Foundation

struct GlobalOptions: ParsableArguments {
    @Flag(name: .long, help: "Output JSON instead of human-readable text.")
    var json: Bool = false

    @Option(name: .long, help: "Override the SwiftData store path.")
    var store: String?

    @Option(name: .long, help: "Workspace root for SKILL.md and workspace tools.")
    var workspace: String?

    @Flag(name: .long, help: "Enable verbose logging.")
    var verbose: Bool = false
}
