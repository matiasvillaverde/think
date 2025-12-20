import Foundation
@testable import Rag
import Testing

@Suite("Embedding Cache")
internal struct EmbeddingCacheTests {
    actor CallCounter {
        private var count: Int = 0

        func increment() -> Int {
            count += 1
            return count
        }

        func current() -> Int {
            count
        }
    }

    actor ComputeCapture {
        private var lastTexts: [String] = []

        func record(_ texts: [String]) {
            lastTexts = texts
        }

        func current() -> [String] {
            lastTexts
        }
    }

    @Test("Embeddings are reused from cache")
    func testCacheReuse() async throws {
        let cache: EmbeddingCache = EmbeddingCache(maxEntries: 4)
        let config: ModelConfiguration = ModelConfiguration(hubRepoId: "test/repo")
        let counter: CallCounter = CallCounter()

        let compute: @Sendable ([String]) async -> [[Float]] = { texts in
            _ = await counter.increment()
            return texts.map { [Float($0.count)] }
        }

        let first: [[Float]] = try await cache.embeddings(
            texts: ["alpha", "beta"],
            modelKey: config.cacheKey,
            compute: compute
        )

        let second: [[Float]] = try await cache.embeddings(
            texts: ["alpha", "beta"],
            modelKey: config.cacheKey,
            compute: compute
        )

        let count: Int = await counter.current()
        #expect(count == 1)
        #expect(first == [[5.0], [4.0]])
        #expect(second == first)
    }

    @Test("Cache evicts least recently used entries")
    func testCacheEvictionUsesLRU() async throws {
        let cache: EmbeddingCache = EmbeddingCache(maxEntries: 2)
        let config: ModelConfiguration = ModelConfiguration(hubRepoId: "test/repo")
        let counter: CallCounter = CallCounter()

        let compute: @Sendable ([String]) async -> [[Float]] = { texts in
            _ = await counter.increment()
            return texts.map { [Float($0.count)] }
        }

        _ = try await cache.embeddings(
            texts: ["alpha", "beta"],
            modelKey: config.cacheKey,
            compute: compute
        )
        _ = try await cache.embeddings(
            texts: ["alpha"],
            modelKey: config.cacheKey,
            compute: compute
        )
        _ = try await cache.embeddings(
            texts: ["gamma"],
            modelKey: config.cacheKey,
            compute: compute
        )

        let alphaHit: [[Float]] = try await cache.embeddings(
            texts: ["alpha"],
            modelKey: config.cacheKey,
            compute: compute
        )
        let countAfterAlpha: Int = await counter.current()
        #expect(countAfterAlpha == 2)
        #expect(alphaHit == [[5.0]])

        _ = try await cache.embeddings(
            texts: ["beta"],
            modelKey: config.cacheKey,
            compute: compute
        )

        let finalCount: Int = await counter.current()
        #expect(finalCount == 3)
    }

    @Test("Cache separates entries by model key")
    func testCacheSeparatesModelKeys() async throws {
        let cache: EmbeddingCache = EmbeddingCache(maxEntries: 4)
        let counter: CallCounter = CallCounter()

        let compute: @Sendable ([String]) async -> [[Float]] = { texts in
            _ = await counter.increment()
            return texts.map { [Float($0.count)] }
        }

        let configA: ModelConfiguration = ModelConfiguration(hubRepoId: "test/repo-a")
        let configB: ModelConfiguration = ModelConfiguration(hubRepoId: "test/repo-b")

        _ = try await cache.embeddings(
            texts: ["same"],
            modelKey: configA.cacheKey,
            compute: compute
        )
        _ = try await cache.embeddings(
            texts: ["same"],
            modelKey: configB.cacheKey,
            compute: compute
        )

        let count: Int = await counter.current()
        #expect(count == 2)
    }

    @Test("Cache deduplicates repeated texts in a batch")
    func testCacheDeduplicatesWithinBatch() async throws {
        let cache: EmbeddingCache = EmbeddingCache(maxEntries: 4)
        let capture: ComputeCapture = ComputeCapture()
        let config: ModelConfiguration = ModelConfiguration(hubRepoId: "test/repo")

        let compute: @Sendable ([String]) async -> [[Float]] = { texts in
            await capture.record(texts)
            return texts.map { [Float($0.count)] }
        }

        let embeddings: [[Float]] = try await cache.embeddings(
            texts: ["repeat", "repeat"],
            modelKey: config.cacheKey,
            compute: compute
        )

        let recorded: [String] = await capture.current()
        #expect(recorded == ["repeat"])
        #expect(embeddings == [[6.0], [6.0]])
    }
}
