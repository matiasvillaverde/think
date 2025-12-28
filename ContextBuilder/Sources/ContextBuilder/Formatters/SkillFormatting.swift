import Abstractions
import Foundation

/// Formats skill context for inclusion in system prompts
internal protocol SkillFormatting {
    /// Formats the skill context for the given action tools
    /// - Parameters:
    ///   - skillContext: The skill context to format
    ///   - actionTools: The tools available for this action
    /// - Returns: A formatted skill section or empty string
    func formatSkillContext(
        _ skillContext: SkillContext,
        actionTools: Set<ToolIdentifier>
    ) -> String
}

/// Default implementation of SkillFormatting
extension SkillFormatting {
    private static var skillComponentsMultiplier: Int {
        // Preallocation multiplier for skill section components.
        // swiftlint:disable:next no_magic_numbers
        3
    }

    internal func formatSkillContext(
        _ skillContext: SkillContext,
        actionTools: Set<ToolIdentifier>
    ) -> String {
        guard !skillContext.isEmpty else {
            return ""
        }

        let toolNames: Set<String> = Set(actionTools.map(\.toolName))
        guard !toolNames.isEmpty else {
            return ""
        }

        let skillsToInclude: [SkillData] = skillContext.skills(for: toolNames)

        guard !skillsToInclude.isEmpty else {
            return ""
        }

        var components: [String] = []
        components.reserveCapacity(
            skillsToInclude.count * Self.skillComponentsMultiplier
        )

        components.append("\n\n# Skills\n")

        for skill in skillsToInclude {
            components.append("\n## \(skill.name)\n")
            components.append(skill.instructions)
            components.append("\n")
        }

        return components.joined()
    }
}
