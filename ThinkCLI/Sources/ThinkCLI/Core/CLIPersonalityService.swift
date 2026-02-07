import Abstractions
import Database
import Foundation

enum CLIPersonalityService {
    static func list(runtime: CLIRuntime) async throws {
        let summaries = try await Task { @MainActor in
            let personalities = try await runtime.database.read(PersonalityCommands.GetAll())
            return personalities.map(PersonalitySummary.init(personality:))
        }.value
        let fallback = summaries.isEmpty
            ? "No personalities."
            : summaries.map { "\($0.id.uuidString)  \($0.name)" }.joined(separator: "\n")
        runtime.output.emit(summaries, fallback: fallback)
    }

    static func create(
        runtime: CLIRuntime,
        name: String,
        description: String,
        instructions: String,
        category: PersonalityCategory
    ) async throws {
        let personalityId = try await runtime.database.write(
            PersonalityCommands.CreateCustom(
                name: name,
                description: description,
                customSystemInstruction: instructions,
                category: category
            )
        )
        runtime.output.emit("Created personality \(personalityId.uuidString)")
    }

    static func update(
        runtime: CLIRuntime,
        personalityId: UUID,
        name: String?,
        description: String?,
        instructions: String?,
        category: PersonalityCategory?
    ) async throws {
        _ = try await runtime.database.write(
            PersonalityCommands.Update(
                personalityId: personalityId,
                name: name,
                description: description,
                systemInstruction: instructions,
                category: category
            )
        )
        runtime.output.emit("Updated personality \(personalityId.uuidString)")
    }

    static func delete(runtime: CLIRuntime, personalityId: UUID) async throws {
        _ = try await runtime.database.write(
            PersonalityCommands.Delete(personalityId: personalityId)
        )
        runtime.output.emit("Deleted personality \(personalityId.uuidString)")
    }

    static func chat(runtime: CLIRuntime, personalityId: UUID) async throws {
        let chatId = try await runtime.database.write(
            PersonalityCommands.GetChat(personalityId: personalityId)
        )
        runtime.output.emit("Personality chat \(chatId.uuidString)")
    }
}
