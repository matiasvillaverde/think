import Database
import Foundation

enum CLISkillsService {
    static func list(runtime: CLIRuntime) async throws {
        let summaries = try await Task { @MainActor in
            let skills = try await runtime.database.read(SkillCommands.GetAll())
            return skills.map(SkillSummary.init(skill:))
        }.value
        let fallback = summaries.isEmpty
            ? "No skills."
            : summaries.map { "\($0.id.uuidString)  \($0.name)" }.joined(separator: "\n")
        runtime.output.emit(summaries, fallback: fallback)
    }

    static func create(
        runtime: CLIRuntime,
        name: String,
        description: String,
        instructions: String,
        tools: [String],
        chatId: UUID?,
        disabled: Bool
    ) async throws {
        let skillId = try await runtime.database.write(
            SkillCommands.Create(
                name: name,
                skillDescription: description,
                instructions: instructions,
                tools: tools,
                isSystem: false,
                isEnabled: !disabled,
                chatId: chatId
            )
        )
        runtime.output.emit("Created skill \(skillId.uuidString)")
    }

    static func enable(runtime: CLIRuntime, skillId: UUID) async throws {
        _ = try await runtime.database.write(
            SkillCommands.SetEnabled(skillId: skillId, isEnabled: true)
        )
        runtime.output.emit("Enabled skill \(skillId.uuidString)")
    }

    static func disable(runtime: CLIRuntime, skillId: UUID) async throws {
        _ = try await runtime.database.write(
            SkillCommands.SetEnabled(skillId: skillId, isEnabled: false)
        )
        runtime.output.emit("Disabled skill \(skillId.uuidString)")
    }
}
