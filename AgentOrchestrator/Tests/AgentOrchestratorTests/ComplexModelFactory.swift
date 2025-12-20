import Abstractions
import Database
import Foundation

internal enum ComplexModelFactory {
    internal static func addComplexModels(_ database: Database) async throws {
        try await database.write(PersonalityCommands.WriteDefault())

        let languageModel: ModelDTO = createLanguageModel()
        let imageModel: ModelDTO = createImageModel()

        try await database.write(ModelCommands.AddModels(modelDTOs: [languageModel, imageModel]))
    }

    private static func createLanguageModel() -> ModelDTO {
        ModelDTO(
            type: .language,
            backend: .mlx,
            name: "test-complex",
            displayName: "Test Complex",
            displayDescription: "Test model",
            skills: ["text"],
            parameters: ComplexTestConstants.languageModelParameters,
            ramNeeded: ComplexTestConstants.languageModelRamBytes,
            size: ComplexTestConstants.languageModelSizeBytes,
            locationHuggingface: "test/complex",
            version: ComplexTestConstants.languageModelVersion,
            architecture: .harmony
        )
    }

    private static func createImageModel() -> ModelDTO {
        ModelDTO(
            type: .diffusion,
            backend: .mlx,
            name: "test-image",
            displayName: "Test Image",
            displayDescription: "Test image model",
            skills: ["image"],
            parameters: ComplexTestConstants.imageModelParameters,
            ramNeeded: ComplexTestConstants.imageModelRamBytes,
            size: ComplexTestConstants.imageModelSizeBytes,
            locationHuggingface: "test/image",
            version: ComplexTestConstants.defaultVersion
        )
    }
}
