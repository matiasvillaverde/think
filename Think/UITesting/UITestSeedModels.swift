import Abstractions
import Database
import Foundation

internal enum UITestSeedModels {
    internal static func ensureLanguageModel(database: DatabaseProtocol) async throws {
        let languageModelName: String = "UITest Language Model (v2)"
        let languageDTO = ModelDTO(
            type: .language,
            backend: .mlx,
            name: languageModelName,
            displayName: languageModelName,
            displayDescription: "Deterministic UI test model",
            tags: ["ui-test"],
            skills: [],
            parameters: 1,
            ramNeeded: 0,
            size: 0,
            locationHuggingface: "mlx-community/uitest-language-model",
            locationKind: .huggingFace,
            version: 2,
            architecture: .unknown
        )

        _ = try await database.write(ModelCommands.AddModels(modelDTOs: [languageDTO]))
        let languageModel: Model = try await database.read(ModelCommands.GetModel(name: languageModelName))
        _ = try await database.write(
            ModelCommands.UpdateModelDownloadProgress(id: languageModel.id, progress: 1.0)
        )
    }
}
