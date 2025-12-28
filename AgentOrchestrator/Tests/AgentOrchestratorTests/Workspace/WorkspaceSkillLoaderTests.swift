import Abstractions
import Foundation
import Testing

@testable import AgentOrchestrator

@Suite("WorkspaceSkillLoader Tests")
internal struct WorkspaceSkillLoaderTests {
    @Test("Loads skills from SKILL.md with YAML front matter")
    internal func loadsSkillsFromWorkspace() throws {
        let rootURL: URL = try createWorkspaceRoot()
        defer { cleanupWorkspace(at: rootURL) }

        let loader: WorkspaceSkillLoader = WorkspaceSkillLoader(rootURL: rootURL)
        let skills: [SkillData] = loader.loadSkills()

        #expect(skills.count == 2)

        let names: Set<String> = Set(skills.map(\.name))
        #expect(names.contains("Weather Skill"))
        #expect(names.contains("Utilities"))

        let weather: SkillData? = skills.first { $0.name == "Weather Skill" }
        #expect(weather?.skillDescription == "Provides weather guidance")
        #expect(weather?.instructions.contains("Use the weather tool") == true)
        #expect(weather?.tools.contains(ToolIdentifier.weather.toolName) == true)
        #expect(weather?.tools.contains(ToolIdentifier.browser.toolName) == true)

        let utilities: SkillData? = skills.first { $0.name == "Utilities" }
        #expect(utilities?.tools.contains(ToolIdentifier.functions.toolName) == true)
        #expect(utilities?.tools.contains(ToolIdentifier.python.toolName) == true)
    }

    private func createWorkspaceRoot() throws -> URL {
        let fileManager: FileManager = FileManager.default
        let rootURL: URL = fileManager.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let skillsURL: URL = rootURL.appendingPathComponent("skills", isDirectory: true)
        let weatherDir: URL = skillsURL.appendingPathComponent("weather", isDirectory: true)
        let toolsDir: URL = skillsURL.appendingPathComponent("tools", isDirectory: true)

        try fileManager.createDirectory(at: weatherDir, withIntermediateDirectories: true)
        try fileManager.createDirectory(at: toolsDir, withIntermediateDirectories: true)
        try writeWeatherSkill(to: weatherDir)
        try writeUtilitiesSkill(to: toolsDir)

        return rootURL
    }

    private func writeWeatherSkill(to directory: URL) throws {
        let weatherSkill: String = [
            "---",
            "name: Weather Skill",
            "description: Provides weather guidance",
            "tools:",
            "  - weather",
            "  - browser.search",
            "---",
            "Use the weather tool and summarize the forecast."
        ].joined(separator: "\n")
        try weatherSkill.write(
            to: directory.appendingPathComponent("SKILL.md"),
            atomically: true,
            encoding: .utf8
        )
    }

    private func writeUtilitiesSkill(to directory: URL) throws {
        let toolsSkill: String = [
            "---",
            "name: Utilities",
            "tools: [functions, python_exec]",
            "enabled: true",
            "---",
            "Use the functions or python tools for quick utilities."
        ].joined(separator: "\n")
        try toolsSkill.write(
            to: directory.appendingPathComponent("skill.md"),
            atomically: true,
            encoding: .utf8
        )
    }

    private func cleanupWorkspace(at rootURL: URL) {
        try? FileManager.default.removeItem(at: rootURL)
    }
}
