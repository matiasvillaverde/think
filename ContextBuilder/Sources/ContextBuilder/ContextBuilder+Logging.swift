import Abstractions
import Foundation
import OSLog

// MARK: - Logging Extensions

extension ContextBuilder {
    // MARK: - Action and Tool Logging

    internal func logActionDetails(_ action: Action) {
        let toolIdentifiers: [String] = action.tools.map(\.rawValue).sorted()

        switch action {
        case .textGeneration(let tools):
            Self.logger.debug("""
                ========== ACTION DETAILS ==========
                Action Type: Text Generation
                Tool Count: \(tools.count)
                Tools in Action: [\(toolIdentifiers.joined(separator: ", "))]
                Has Reasoning Tool: \(tools.contains(.reasoning))
                Raw Action: .textGeneration(\(tools.map(\.rawValue).sorted()))
                ========== ACTION DETAILS END ==========
                """)

        case .imageGeneration(let tools):
            Self.logger.debug("""
                ========== ACTION DETAILS ==========
                Action Type: Image Generation
                Tool Count: \(tools.count)
                Tools in Action: [\(toolIdentifiers.joined(separator: ", "))]
                Raw Action: .imageGeneration(\(tools.map(\.rawValue).sorted()))
                ========== ACTION DETAILS END ==========
                """)
        }
    }

    internal func logToolComparison(
        requested: Set<ToolIdentifier>,
        fetched: [ToolDefinition]
    ) {
        let requestedNames: Set<String> = Set(requested.map(\.rawValue))
        let fetchedNames: Set<String> = Set(fetched.map(\.name))
        let missing: Set<String> = requestedNames.subtracting(fetchedNames)
        let extra: Set<String> = fetchedNames.subtracting(requestedNames)

        let requestedTools: String = requested
            .map(\.rawValue)
            .sorted()
            .joined(separator: ", ")

        let fetchedTools: String = fetched
            .map(\.name)
            .sorted()
            .joined(separator: ", ")

        let missingText: String = missing.isEmpty
            ? "None"
            : missing.sorted().joined(separator: ", ")

        let extraText: String = extra.isEmpty
            ? "None"
            : extra.sorted().joined(separator: ", ")

        let matchStatus: String = missing.isEmpty && extra.isEmpty
            ? "✅ Perfect Match"
            : "⚠️ Mismatch"

        // Build tool details more efficiently
        var toolDetailComponents: [String] = []
        toolDetailComponents.reserveCapacity(fetched.count)
        for tool in fetched {
            let limit: Int = Constants.toolDescriptionPreviewLimit
            let preview: String = String(tool.description.prefix(limit))
            let needsEllipsis: Bool = tool.description.count > limit
            toolDetailComponents.append("  - \(tool.name): \(preview)\(needsEllipsis ? "..." : "")")
        }
        let toolDetails: String = toolDetailComponents.joined(separator: "\n")

        Self.logger.debug("""
            ========== TOOL RESOLUTION ==========
            Tools Requested: \(requested.count) - [\(requestedTools)]
            Definitions Fetched: \(fetched.count) - [\(fetchedTools)]

            Detailed Comparison:
            - Missing Definitions: \(missingText)
            - Extra Definitions: \(extraText)
            - Match Status: \(matchStatus)

            Fetched Tool Details:
            \(toolDetails)
            ========== TOOL RESOLUTION END ==========
            """)
    }
}
