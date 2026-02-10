import Abstractions
import SwiftUI

internal enum CapabilitiesToolSupport {
    /// Tools we are confident can be configured and surfaced as text tool-calls across platforms.
    ///
    /// This intentionally excludes tools that may require additional runtime wiring
    /// (e.g. workspace root, sub-agent orchestration) until we have a dedicated
    /// availability signal for them.
    static func supportedTextTools() -> Set<ToolIdentifier> {
        var tools: Set<ToolIdentifier> = [
            .browser,
            .duckduckgo,
            .braveSearch,
            .weather,
            .python,
            .functions,
            .memory
        ]

        #if os(iOS)
            tools.insert(.healthKit)
        #endif

        return tools
    }
}
