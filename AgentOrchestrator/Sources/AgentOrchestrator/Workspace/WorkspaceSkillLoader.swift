import Abstractions
import Foundation
import OSLog

/// Loads skills from a workspace skills directory.
internal struct WorkspaceSkillLoader {
    private static let logger: Logger = Logger(
        subsystem: AgentOrchestratorConfiguration.shared.logging.subsystem,
        category: "WorkspaceSkillLoader"
    )

    private let rootURL: URL
    private let fileManager: FileManager

    internal init(rootURL: URL, fileManager: FileManager = .default) {
        self.rootURL = rootURL
        self.fileManager = fileManager
    }

    internal func loadSkills() -> [SkillData] {
        let directories: [URL] = skillDirectories()
        var skills: [SkillData] = []
        for directory in directories {
            if let skill = loadSkill(from: directory) {
                skills.append(skill)
            }
        }
        return skills
    }

    private func skillDirectories() -> [URL] {
        let entries: [URL] = skillDirectoryEntries()
        return entries.filter { entry in isDirectory(entry) }
    }

    private func skillDirectoryEntries() -> [URL] {
        let skillsDirectory: URL = rootURL.appendingPathComponent("skills", isDirectory: true)
        guard fileManager.fileExists(atPath: skillsDirectory.path) else {
            return []
        }

        return (try? fileManager.contentsOfDirectory(
            at: skillsDirectory,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        )) ?? []
    }

    private func isDirectory(_ url: URL) -> Bool {
        let values: URLResourceValues? = try? url.resourceValues(forKeys: [.isDirectoryKey])
        return values?.isDirectory == true
    }

    private func loadSkill(from directory: URL) -> SkillData? {
        guard let skillFileURL: URL = findSkillFile(in: directory) else {
            return nil
        }

        do {
            let content: String = try String(contentsOf: skillFileURL, encoding: .utf8)
            let parsed: ParsedSkillFile = parseSkillFile(content)
            let fileInfo: SkillFileInfo = try readSkillFileInfo(from: skillFileURL)
            return buildSkillData(parsed: parsed, directory: directory, info: fileInfo)
        } catch {
            Self.logger.warning(
                "Failed to load skill at \(directory.lastPathComponent, privacy: .public)"
            )
            return nil
        }
    }

    private func readSkillFileInfo(from url: URL) throws -> SkillFileInfo {
        let attributes: [FileAttributeKey: Any] = try fileManager.attributesOfItem(
            atPath: url.path
        )
        let createdAt: Date = attributes[.creationDate] as? Date ?? Date()
        let updatedAt: Date = attributes[.modificationDate] as? Date ?? Date()
        return SkillFileInfo(createdAt: createdAt, updatedAt: updatedAt)
    }

    private func buildSkillData(
        parsed: ParsedSkillFile,
        directory: URL,
        info: SkillFileInfo
    ) -> SkillData {
        let name: String = parsed.name ?? directory.lastPathComponent
        let description: String = parsed.description ?? ""
        let tools: [String] = normalizeTools(parsed.tools)

        return SkillData(
            id: UUID(),
            createdAt: info.createdAt,
            updatedAt: info.updatedAt,
            name: name,
            skillDescription: description,
            instructions: parsed.instructions,
            tools: tools,
            isSystem: false,
            isEnabled: parsed.isEnabled,
            chatId: nil
        )
    }

    private func findSkillFile(in directory: URL) -> URL? {
        let candidates: [URL] = [
            directory.appendingPathComponent("SKILL.md"),
            directory.appendingPathComponent("skill.md")
        ]
        for candidate in candidates where fileManager.fileExists(atPath: candidate.path) {
            return candidate
        }
        return nil
    }

    private func normalizeTools(_ tools: [String]) -> [String] {
        let trimmed: [String] = tools
            .map { tool in tool.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { tool in !tool.isEmpty }

        return trimmed.map { tool in
            if let identifier = ToolIdentifier.from(toolName: tool) {
                return identifier.toolName
            }

            if let identifier = ToolIdentifier.allCases.first(
                where: { identifier in identifier.rawValue.lowercased() == tool.lowercased() }
            ) {
                return identifier.toolName
            }

            return tool
        }
    }

    internal struct SkillFileInfo {
        internal let createdAt: Date
        internal let updatedAt: Date
    }
}
