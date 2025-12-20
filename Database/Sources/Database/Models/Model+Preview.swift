import Foundation
import Abstractions

// MARK: - Preview
#if DEBUG
extension Model {
    @MainActor public static let preview: Model = {
        Model.previews.first!
    }()

    @MainActor public static let previews: [Model] = {
        // Define all possible states with progress values
        let statesWithProgress: [(state: Model.State, progress: Double)] = [
            (.notDownloaded, 0.0),
            (.downloadingActive, 0.25),
            (.downloadingPaused, 0.5),
            (.downloadingActive, 0.75),
            (.downloaded, 1.0)
        ]

        // Create simple mock models for preview
        let mockConfigs = [
            ("Llama 3.1 8B", SendableModel.ModelType.language, SendableModel.Backend.mlx),
            ("Qwen 2.5 14B", SendableModel.ModelType.deepLanguage, SendableModel.Backend.mlx),
            ("Stable Diffusion", SendableModel.ModelType.diffusion, SendableModel.Backend.mlx),
            ("Code Llama", SendableModel.ModelType.language, SendableModel.Backend.mlx),
            ("Mistral Nemo", SendableModel.ModelType.language, SendableModel.Backend.mlx)
        ]

        var models: [Model] = []

        // Create models with different states
        for (index, config) in mockConfigs.enumerated() {
            let stateIndex = index % statesWithProgress.count
            let (state, progress) = statesWithProgress[stateIndex]

            let dto = ModelDTO(
                type: config.1,
                backend: config.2,
                name: config.0,
                displayName: config.0,
                displayDescription: "Mock model for preview",
                skills: [],
                parameters: UInt64.random(in: 1_000_000_000...70_000_000_000),
                ramNeeded: UInt64.random(in: 4.gigabytes...16.gigabytes),
                size: UInt64.random(in: 2.gigabytes...8.gigabytes),
                locationHuggingface: config.0.lowercased().replacingOccurrences(of: " ", with: "-"),
                version: 2,
                architecture: .unknown
            )

            // swiftlint:disable:next force_try
            let model = try! dto.createModel()
            model.state = state
            model.downloadProgress = progress
            models.append(model)
        }

        return models
    }()
}

private extension UInt64 {
    static var gigabytes: UInt64 { 1_073_741_824 }
}
#endif
