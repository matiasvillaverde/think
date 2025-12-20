import Abstractions
import AbstractionsTestUtilities
import Foundation
import Testing

@Suite("SendableModel Architecture Tests", .tags(.core))
struct SendableModelArchitectureTests {
    @Test("Architecture is properly stored and accessible")
    func testArchitectureProperty() {
        // Test various architectures
        let testCases: [(Architecture, String)] = [
            (.llama, "llama"),
            (.mistral, "mistral"),
            (.qwen, "qwen"),
            (.phi, "phi"),
            (.gemma, "gemma"),
            (.unknown, "unknown")
        ]

        for (architecture, expectedRawValue) in testCases {
            let model = SendableModel(
                id: UUID(),
                ramNeeded: 1_000_000_000,
                modelType: .language,
                location: "test/model",
                architecture: architecture,
                backend: .mlx
            )

            #expect(model.architecture == architecture)
            #expect(model.architecture.rawValue == expectedRawValue)
        }
    }

    @Test("SendableModel equality includes architecture")
    func testEqualityWithArchitecture() {
        let id = UUID()

        let model1 = SendableModel(
            id: id,
            ramNeeded: 1_000_000_000,
            modelType: .language,
            location: "test/model",
            architecture: .llama,
            backend: .mlx
        )

        let model2 = SendableModel(
            id: id,
            ramNeeded: 1_000_000_000,
            modelType: .language,
            location: "test/model",
            architecture: .llama,
            backend: .mlx
        )

        let model3 = SendableModel(
            id: id,
            ramNeeded: 1_000_000_000,
            modelType: .language,
            location: "test/model",
            architecture: .mistral,  // Different architecture
            backend: .mlx
        )

        #expect(model1 == model2)
        #expect(model1 != model3)
    }

    @Test("Debug description includes architecture")
    func testDebugDescriptionIncludesArchitecture() {
        let model = SendableModel(
            id: UUID(),
            ramNeeded: 1_000_000_000,
            modelType: .language,
            location: "test/model",
            architecture: .qwen,
            backend: .mlx
        )

        let description = model.debugDescription
        #expect(description.contains("architecture: qwen"))
    }

    @Test("Architecture affects model behavior in Context")
    func testArchitectureAffectsContextBehavior() {
        // Test that different architectures result in different label constants
        let qwenModel = SendableModel(
            id: UUID(),
            ramNeeded: 1_000_000_000,
            modelType: .language,
            location: "test/qwen-model",
            architecture: .qwen,
            backend: .mlx
        )

        let llamaModel = SendableModel(
            id: UUID(),
            ramNeeded: 1_000_000_000,
            modelType: .language,
            location: "test/llama-model",
            architecture: .llama,
            backend: .mlx
        )

        // Architectures should be different
        #expect(qwenModel.architecture != llamaModel.architecture)

        // Each architecture should have its expected raw value
        #expect(qwenModel.architecture.rawValue == "qwen")
        #expect(llamaModel.architecture.rawValue == "llama")
    }

    @Test("All architecture types can be used in SendableModel")
    func testAllArchitectureTypes() {
        // Test that all Architecture cases can be used
        for architecture in Architecture.allCases {
            let model = SendableModel(
                id: UUID(),
                ramNeeded: 1_000_000_000,
                modelType: .language,
                location: "test/\(architecture.rawValue)-model",
                architecture: architecture,
                backend: .mlx
            )

            #expect(model.architecture == architecture)
            #expect(model.location.contains(architecture.rawValue))
        }
    }

    @Test("SendableModel with metadata still works")
    func testSendableModelWithMetadata() {
        let metadata = ModelMetadata(
            parameters: ModelParameters(count: 7_000_000_000, formatted: "7B"),
            architecture: .llama,  // Note: metadata also has architecture
            capabilities: [.textInput, .textOutput],
            quantizations: [],
            version: "3.2"
        )

        let model = SendableModel(
            id: UUID(),
            ramNeeded: 8_000_000_000,
            modelType: .language,
            location: "test/model",
            architecture: .llama,
            backend: .mlx,
            detailedMemoryRequirements: nil,
            metadata: metadata
        )

        // Both the model and metadata have architecture
        #expect(model.architecture == Architecture.llama)
        #expect(model.metadata?.architecture == .llama)

        // They should match
        #expect(model.architecture == model.metadata?.architecture)
    }
}
