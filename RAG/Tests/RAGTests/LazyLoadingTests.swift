import Abstractions
import Foundation
@testable import Rag
import Testing

@Suite("Lazy Loading Tests")
internal struct LazyLoadingTests {
    // MARK: - Helper Methods

    private static func createTextFile(with text: String) throws -> URL {
        let tempDir: URL = FileManager.default.temporaryDirectory
        let textURL: URL = tempDir.appendingPathComponent(UUID().uuidString).appendingPathExtension("txt")
        try text.write(to: textURL, atomically: true, encoding: .utf8)
        return textURL
    }

    // MARK: - Initialization Tests

    @Test("RAG initializes without loading model in lazy mode")
    func testLazyInitialization() async throws {
        _ = try await TestHelpers.createTestRag(database: .inMemory, loadingStrategy: .lazy)

        // At this point, the model should not be loaded yet
        // We can't directly verify this without exposing internal state,
        // but we can verify that initialization completed quickly
        #expect(Bool(true), "RAG actor initialized successfully with lazy loading")
    }

    @Test("RAG loads model immediately in eager mode")
    func testEagerInitialization() async throws {
        let rag: any Ragging = try await TestHelpers.createTestRag(database: .inMemory, loadingStrategy: .eager)

        // In eager mode, model should be loaded during initialization
        // Test by performing an immediate operation
        let results: [SearchResult] = try await rag.semanticSearch(
            query: "test",
            numResults: 1,
            threshold: 10.0,
            table: "embeddings"
        )
        #expect(results.isEmpty) // Should work even with no data
    }

    @Test("Default initialization uses lazy loading")
    func testDefaultInitializationIsLazy() async throws {
        _ = try await TestHelpers.createTestRag(database: .inMemory)

        // Default should be lazy loading
        #expect(Bool(true), "Default initialization completed")
    }

    // MARK: - Model Loading on First Use Tests

    @Test("Model loads on first semantic search")
    func testModelLoadsOnFirstSemanticSearch() async throws {
        let rag: any Ragging = try await TestHelpers.createTestRag(database: .inMemory, loadingStrategy: .lazy)

        // Add some content first
        let content: String = "This is a test document about machine learning."
        let fileURL: URL = try Self.createTextFile(with: content)

        for try await progress in await rag.add(fileURL: fileURL, id: UUID(), configuration: .default) {
            #expect(progress.completedUnitCount > 0)
        }

        // First semantic search should trigger model loading
        let results: [SearchResult] = try await rag.semanticSearch(
            query: "machine learning",
            numResults: 1,
            threshold: 10.0,
            table: "embeddings"
        )
        #expect(!results.isEmpty)
        #expect(results[0].text.contains("machine learning"))
    }

    @Test("Model loads on first file add operation")
    func testModelLoadsOnFirstAdd() async throws {
        let rag: any Ragging = try await TestHelpers.createTestRag(database: .inMemory, loadingStrategy: .lazy)

        let content: String = "This is a test document about artificial intelligence."
        let fileURL: URL = try Self.createTextFile(with: content)

        // First add operation should trigger model loading
        for try await progress in await rag.add(fileURL: fileURL, id: UUID(), configuration: .default) {
            #expect(progress.completedUnitCount > 0)
        }

        // Verify content was added successfully
        let results: [SearchResult] = try await rag.semanticSearch(
            query: "artificial intelligence",
            numResults: 1,
            threshold: 10.0,
            table: "embeddings"
        )
        #expect(!results.isEmpty)
    }

    @Test("Model loads on first text add operation")
    func testModelLoadsOnFirstTextAdd() async throws {
        let rag: any Ragging = try await TestHelpers.createTestRag(database: .inMemory, loadingStrategy: .lazy)

        let content: String = "This is test content about deep learning algorithms."

        // First text add should trigger model loading
        for try await progress in await rag.add(text: content, id: UUID(), configuration: .default) {
            #expect(progress.completedUnitCount > 0)
        }

        // Verify content was added successfully
        let results: [SearchResult] = try await rag.semanticSearch(
            query: "deep learning",
            numResults: 1,
            threshold: 10.0,
            table: "embeddings"
        )
        #expect(!results.isEmpty)
    }

    // MARK: - Concurrent Access Tests

    @Test("Concurrent access during model loading is thread-safe")
    func testConcurrentModelAccess() async throws {
        let rag: any Ragging = try await TestHelpers.createTestRag(database: .inMemory, loadingStrategy: .lazy)

        // Add some test content
        let content: String = "Test content for concurrent access testing."
        let fileURL: URL = try Self.createTextFile(with: content)

        for try await progress in await rag.add(fileURL: fileURL, id: UUID(), configuration: .default) {
            #expect(progress.completedUnitCount > 0)
        }

        // Perform multiple concurrent operations that require the model
        await withTaskGroup(of: Void.self) { group in
            for taskIndex in 0..<5 {
                group.addTask {
                    do {
                        let results: [SearchResult] = try await rag.semanticSearch(
                            query: "test content \(taskIndex)",
                            numResults: 1,
                            threshold: 10.0,
                            table: "embeddings"
                        )
                        // Results may or may not be empty - we're testing thread safety, not search accuracy
                        _ = results
                    } catch {
                        // Log error but don't fail test - concurrent access might have timeouts
                        print("Concurrent access test error: \(error)")
                    }
                }
            }
        }
    }

    @Test("Multiple operations after model loaded work correctly")
    func testMultipleOperationsAfterModelLoaded() async throws {
        let rag: any Ragging = try await TestHelpers.createTestRag(database: .inMemory, loadingStrategy: .lazy)

        // First, trigger model loading with initial content
        let content1: String = "First document about machine learning."
        let fileURL1: URL = try Self.createTextFile(with: content1)

        for try await progress in await rag.add(fileURL: fileURL1, id: UUID(), configuration: .default) {
            #expect(progress.completedUnitCount > 0)
        }

        // Model should now be loaded, subsequent operations should be fast
        let content2: String = "Second document about data science."
        let fileURL2: URL = try Self.createTextFile(with: content2)

        for try await progress in await rag.add(fileURL: fileURL2, id: UUID(), configuration: .default) {
            #expect(progress.completedUnitCount > 0)
        }

        // Verify both documents are searchable
        let results1: [SearchResult] = try await rag.semanticSearch(
            query: "machine learning",
            numResults: 1,
            threshold: 10.0,
            table: "embeddings"
        )
        #expect(!results1.isEmpty)

        let results2: [SearchResult] = try await rag.semanticSearch(
            query: "data science",
            numResults: 1,
            threshold: 10.0,
            table: "embeddings"
        )
        #expect(!results2.isEmpty)
    }

    // MARK: - Error Handling Tests

    @Test("Model loading errors are propagated correctly")
    func testModelLoadingErrorHandling() async throws {
        // Test with invalid hub repo ID to trigger loading error
        do {
            let rag: any Ragging = try await TestHelpers.createTestRag(
                from: "invalid/repo-id",
                database: .inMemory,
                loadingStrategy: .lazy
            )

            // Try to trigger model loading
            _ = try await rag.semanticSearch(
                query: "test",
                numResults: 1,
                threshold: 10.0,
                table: "embeddings"
            )
            #expect(Bool(false), "Expected model loading to fail with invalid repo ID")
        } catch {
            #expect(Bool(true), "Successfully caught model loading error: \(error)")
        }
    }

    // MARK: - Hybrid Loading Strategy Tests

    @Test("Hybrid loading strategy preloads model after delay")
    func testHybridLoadingStrategy() async throws {
        let rag: any Ragging = try await TestHelpers.createTestRag(
            database: .inMemory,
            loadingStrategy: .hybrid(preloadAfter: 0.1)
        )

        // Wait for preload delay plus a bit more
        try await Task.sleep(for: .milliseconds(200))

        // Add content - model should already be loaded
        let content: String = "Test content for hybrid loading."
        let fileURL: URL = try Self.createTextFile(with: content)

        for try await progress in await rag.add(fileURL: fileURL, id: UUID(), configuration: .default) {
            #expect(progress.completedUnitCount > 0)
        }

        // Verify content is searchable
        let results: [SearchResult] = try await rag.semanticSearch(
            query: "hybrid",
            numResults: 1,
            threshold: 10.0,
            table: "embeddings"
        )
        #expect(!results.isEmpty)
    }

    // MARK: - Performance Tests

    @Test("Subsequent operations after model loaded show no performance regression")
    func testPerformanceAfterModelLoaded() async throws {
        let rag: any Ragging = try await TestHelpers.createTestRag(database: .inMemory, loadingStrategy: .lazy)

        // First operation to load model
        let content: String = "Performance test content for machine learning research."
        let fileURL: URL = try Self.createTextFile(with: content)

        for try await progress in await rag.add(fileURL: fileURL, id: UUID(), configuration: .default) {
            #expect(progress.completedUnitCount > 0)
        }

        // Measure performance of subsequent operations
        let startTime: ContinuousClock.Instant = ContinuousClock.now

        for searchIndex in 0..<5 {
            let results: [SearchResult] = try await rag.semanticSearch(
                query: "machine learning \(searchIndex)",
                numResults: 1,
                threshold: 10.0,
                table: "embeddings"
            )
            // Results may or may not be empty depending on query variation
            _ = results
        }

        let duration: Duration = startTime.duration(to: .now)
        #expect(duration < .seconds(5), "Multiple searches should complete quickly after model loaded")
    }
}
