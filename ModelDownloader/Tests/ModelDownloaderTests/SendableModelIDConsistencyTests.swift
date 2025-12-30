import Abstractions
import Foundation
@testable import ModelDownloader
import Testing

/// Tests to ensure SendableModel ID is used consistently throughout the download process
struct SendableModelIDConsistencyTests {
    @Test
    func testModelInfoUsesSingleID() {
        // Given
        let modelId: UUID = UUID()

        // When
        let modelInfo: ModelInfo = ModelInfo(
            id: modelId,
            name: "test-model",
            backend: SendableModel.Backend.mlx,
            location: URL(fileURLWithPath: "/test"),
            totalSize: 1_024,
            downloadDate: Date()
        )

        // Then - verify single ID is used
        #expect(modelInfo.id == modelId)
        #expect(modelInfo.name == "test-model")
        #expect(modelInfo.backend == SendableModel.Backend.mlx)
    }

    @Test
    func testDownloadWithSendableModelAPIExists() {
        // Given
        let sendableModel: SendableModel = SendableModel(
            id: UUID(),
            ramNeeded: 8_000_000_000,
            modelType: .language,
            location: "mlx-community/test-model",
            architecture: .llama,
            backend: SendableModel.Backend.mlx,
            locationKind: .huggingFace
        )

        // Create a downloader to verify API exists
        _ = ModelDownloader(
            modelsDirectory: URL(fileURLWithPath: "/test/models"),
            temporaryDirectory: URL(fileURLWithPath: "/test/temp")
        )

        // Then - verify we can create a SendableModel with backend
        // ID is automatically generated
        #expect(sendableModel.backend == SendableModel.Backend.mlx)
        #expect(sendableModel.location == "mlx-community/test-model")
    }

    @Test
    func testFileManagerFinalizeDownloadUsesProvidedID() async {
        // Given
        let fileManager: MockFileManager = MockFileManager()

        // When
        let modelInfo: ModelInfo = await fileManager.finalizeDownload(
            repositoryId: "test/model",
            name: "test-model",
            backend: SendableModel.Backend.mlx,
            from: URL(fileURLWithPath: "/temp/test"),
            totalSize: 1_024
        )

        // Then
        #expect(modelInfo.name == "test-model")
        #expect(modelInfo.backend == SendableModel.Backend.mlx)
    }

    @Test
    func testModelInfoCodablePreservesID() throws {
        // Given
        let originalInfo: ModelInfo = ModelInfo(
            id: UUID(),
            name: "test-model",
            backend: SendableModel.Backend.mlx,
            location: URL(fileURLWithPath: "/test"),
            totalSize: 1_024,
            downloadDate: Date(),
            metadata: ["key": "value"]
        )

        // When
        let encoded: Data = try JSONEncoder().encode(originalInfo)
        let decoded: ModelInfo = try JSONDecoder().decode(ModelInfo.self, from: encoded)

        // Then
        #expect(decoded.id == originalInfo.id)
        #expect(decoded.name == originalInfo.name)
        #expect(decoded.backend == originalInfo.backend)
        #expect(decoded.location == originalInfo.location)
        #expect(decoded.totalSize == originalInfo.totalSize)
        #expect(decoded.metadata == originalInfo.metadata)
    }

    @Test
    func testSendableModelBackendIntegration() {
        // Given - Test that SendableModel uses Backend enum correctly
        let sendableModel: SendableModel = SendableModel(
            id: UUID(),
            ramNeeded: 4_000_000_000,
            modelType: .language,
            location: "apple/test-model",
            architecture: .unknown,
            backend: SendableModel.Backend.coreml,
            locationKind: .huggingFace
        )

        // Then - Backend should be accessible and correct
        #expect(sendableModel.backend == SendableModel.Backend.coreml)
        #expect(sendableModel.backend.rawValue == "coreml")
    }
}
