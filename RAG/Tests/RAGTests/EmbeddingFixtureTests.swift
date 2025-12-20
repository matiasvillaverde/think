import Abstractions
import CoreML
import Embeddings
import Foundation
@testable import Rag
import Testing

@Suite("Embedding Fixtures")
internal struct EmbeddingFixtureTests {
    @Test("Embedding matches golden fixture")
    func testEmbeddingMatchesFixture() async throws {
        if ProcessInfo.processInfo.environment["GENERATE_RAG_EMBEDDING_FIXTURE"] == "1" {
            return
        }

        let fixture: EmbeddingFixture = try loadFixture()

        let model: Bert.ModelBundle = try await Bert.loadModelBundle(from: TestHelpers.localModelURL)
        let tensor: MLTensor = try model.encode(fixture.text)
        let embedding: [Float] = try await tensor.convertTensorToVector()

        #expect(embedding.count == fixture.dimension)
        #expect(embedding.count == Abstractions.Constants.defaultEmbeddingDimension)
        #expect(fixture.model == "sentence-transformers/all-MiniLM-L6-v2")

        let maxAbsDiff: Float = maxAbsoluteDifference(lhs: embedding, rhs: fixture.embedding)
        let cosine: Double = cosineSimilarity(lhs: embedding, rhs: fixture.embedding)

        #expect(cosine > 0.999)
        #expect(maxAbsDiff < 0.0001)
    }

    private func loadFixture() throws -> EmbeddingFixture {
        let url: URL = try EmbeddingFixturePaths.resourceURL()
        let data: Data = try Data(contentsOf: url)
        return try JSONDecoder().decode(EmbeddingFixture.self, from: data)
    }

    private func maxAbsoluteDifference(lhs: [Float], rhs: [Float]) -> Float {
        zip(lhs, rhs).map { abs($0 - $1) }.max() ?? 0
    }

    private func cosineSimilarity(lhs: [Float], rhs: [Float]) -> Double {
        let dot: Double = zip(lhs, rhs).reduce(0.0) { partial, pair in
            partial + Double(pair.0 * pair.1)
        }
        let lhsNorm: Double = sqrt(lhs.reduce(0.0) { $0 + Double($1 * $1) })
        let rhsNorm: Double = sqrt(rhs.reduce(0.0) { $0 + Double($1 * $1) })
        guard lhsNorm > 0, rhsNorm > 0 else {
            return 0
        }
        return dot / (lhsNorm * rhsNorm)
    }
}
