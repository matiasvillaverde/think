import CoreML
import Embeddings
import Foundation
@testable import Rag
import Testing

@Suite("Embedding Fixture Generation")
internal struct EmbeddingFixtureGenerator {
    @Test("Generate embedding fixture")
    func generateFixture() async throws {
        guard ProcessInfo.processInfo.environment["GENERATE_RAG_EMBEDDING_FIXTURE"] == "1" else {
            return
        }

        let text: String = "The quick brown fox jumps over the lazy dog."
        let model: Bert.ModelBundle = try await Bert.loadModelBundle(from: TestHelpers.localModelURL)
        let tensor: MLTensor = try model.encode(text)
        let embedding: [Float] = await tensor.convertTensorToVector()

        let fixture: EmbeddingFixture = EmbeddingFixture(
            model: "sentence-transformers/all-MiniLM-L6-v2",
            text: text,
            dimension: embedding.count,
            embedding: embedding
        )

        let fileURL: URL = EmbeddingFixturePaths.fileURLForGeneration()
        try FileManager.default.createDirectory(
            at: fileURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )

        let encoder: JSONEncoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        let data: Data = try encoder.encode(fixture)
        try data.write(to: fileURL, options: [.atomic])

        #expect(FileManager.default.fileExists(atPath: fileURL.path))
    }
}
