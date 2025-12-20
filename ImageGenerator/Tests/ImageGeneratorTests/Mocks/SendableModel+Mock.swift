import Abstractions
import Foundation

// Mock SendableModel helper
extension SendableModel {
    static func mock(
        id: UUID = UUID(),
        name: String = "Test Model",
        modelType: ModelType = .diffusion
    ) -> SendableModel {
        let metadata = ModelMetadata(
            parameters: ModelParameters(
                count: 850_000_000, // Typical SD model size
                formatted: "850M"
            ),
            architecture: .stableDiffusion,
            capabilities: [.imageOutput],
            quantizations: [],
            version: nil,
            contextLength: nil
        )

        return SendableModel(
            id: id,
            ramNeeded: 1_000_000_000,
            modelType: modelType,
            location: name.lowercased().replacingOccurrences(of: " ", with: "-"),
            architecture: .stableDiffusion,
            backend: .coreml,
            detailedMemoryRequirements: nil,
            metadata: metadata
        )
    }
}
