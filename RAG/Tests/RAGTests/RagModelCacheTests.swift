import Abstractions
@testable import Rag
import Testing

@Suite("RAG Model Cache")
internal struct RagModelCacheTests {
    @Test("Model cache reuses model across instances")
    func testModelCacheReusesModelAcrossInstances() async throws {
        let cache: RagModelCache = RagModelCache.shared
        await cache.reset()

        let rag1: Rag = try await TestHelpers.createTestRag(
            database: .inMemory,
            loadingStrategy: .lazy
        )
        _ = try await rag1.semanticSearch(
            query: "cache test",
            numResults: 1,
            threshold: 10.0
        )

        let rag2: Rag = try await TestHelpers.createTestRag(
            database: .inMemory,
            loadingStrategy: .lazy
        )
        _ = try await rag2.semanticSearch(
            query: "cache test",
            numResults: 1,
            threshold: 10.0
        )

        let loadCount: Int = await cache.currentLoadCount()
        #expect(loadCount == 1)
        await cache.reset()
    }
}
