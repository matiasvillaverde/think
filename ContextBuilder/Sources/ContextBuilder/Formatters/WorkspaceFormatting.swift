import Abstractions
import Foundation

/// Protocol for formatting workspace bootstrap context
internal protocol WorkspaceFormatting {
    func formatWorkspaceContext(_ workspaceContext: WorkspaceContext) -> String
}

/// Default implementation of WorkspaceFormatting
extension WorkspaceFormatting {
    internal func formatWorkspaceContext(_ workspaceContext: WorkspaceContext) -> String {
        guard !workspaceContext.sections.isEmpty else {
            return ""
        }

        var components: [String] = []
        components.append("\n\n# Workspace Context\n")

        for section in workspaceContext.sections {
            let trimmedContent: String = section.content.trimmingCharacters(
                in: .whitespacesAndNewlines
            )
            guard !trimmedContent.isEmpty else {
                continue
            }
            components.append("\n## \(section.title)\n")
            components.append("\(trimmedContent)\n")
        }

        return components.joined()
    }
}
