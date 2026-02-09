import Abstractions
import Foundation
@testable import Rag
import Testing

@Suite("Memory Benchmark Tests")
internal struct MemoryBenchmarkTests {
    // MARK: - Helper Methods

    private func getMemoryUsage() -> Int64 {
        var info: mach_task_basic_info = mach_task_basic_info()
        var count: mach_msg_type_number_t = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size) / 4

        let result: kern_return_t = withUnsafeMutablePointer(to: &info) { infoPointer in
            infoPointer.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { integerPointer in
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), integerPointer, &count)
            }
        }

        guard result == KERN_SUCCESS else {
            return 0
        }

        return Int64(info.resident_size)
    }

    private static func createTextFile(with text: String) throws -> URL {
        let tempDir: URL = FileManager.default.temporaryDirectory
        let textURL: URL = tempDir.appendingPathComponent(UUID().uuidString).appendingPathExtension("txt")
        try text.write(to: textURL, atomically: true, encoding: .utf8)
        return textURL
    }

    // MARK: - Memory Usage Tests

    @Test("Memory usage without RAG access remains minimal")
    func testMemoryFootprintWithoutAccess() async throws {
        guard TestHelpers.isLocalModelAvailable else {
            return
        }
        let initialMemory: Int64 = getMemoryUsage()

        // Create RAG instance with lazy loading
        _ = try await TestHelpers.createTestRag(database: .inMemory, loadingStrategy: .lazy)

        let afterInitMemory: Int64 = getMemoryUsage()
        let memoryIncrease: Int64 = afterInitMemory - initialMemory

        // Allow for some overhead but should be much less than 90MB
        // Using 10MB as a generous threshold (actual should be much less)
        #expect(
            memoryIncrease < 10_000_000,
            "Memory increase should be less than 10MB, was \(memoryIncrease) bytes"
        )

        print("Memory increase after lazy RAG initialization: \(memoryIncrease) bytes")
    }

    @Test("Memory usage with RAG access shows model loading")
    func testMemoryFootprintWithAccess() async throws {
        guard TestHelpers.isLocalModelAvailable else {
            return
        }
        let rag: Ragging = try await TestHelpers.createTestRag(database: .inMemory, loadingStrategy: .lazy)
        let beforeUseMemory: Int64 = getMemoryUsage()

        // Trigger model loading by adding content
        let content: String = "Test content to trigger model loading for memory measurement."
        let fileURL: URL = try Self.createTextFile(with: content)

        for try await progress in await rag.add(fileURL: fileURL, id: UUID(), configuration: .default) {
            #expect(progress.completedUnitCount > 0)
        }

        let afterUseMemory: Int64 = getMemoryUsage()
        let memoryIncrease: Int64 = afterUseMemory - beforeUseMemory

        // Model loading should increase memory significantly (expecting ~90MB but allowing variance)
        #expect(
            memoryIncrease > 50_000_000,
            "Model should use significant memory, increase was \(memoryIncrease) bytes"
        )

        print("Memory increase after model loading: \(memoryIncrease) bytes")
    }

    @Test("Eager loading uses memory immediately")
    func testEagerLoadingMemoryUsage() async throws {
        guard TestHelpers.isLocalModelAvailable else {
            return
        }
        let initialMemory: Int64 = getMemoryUsage()

        // Create RAG instance with eager loading
        _ = try await TestHelpers.createTestRag(database: .inMemory, loadingStrategy: .eager)

        let afterInitMemory: Int64 = getMemoryUsage()
        let memoryIncrease: Int64 = afterInitMemory - initialMemory

        // Eager loading should use significant memory immediately
        #expect(
            memoryIncrease > 50_000_000,
            "Eager loading should use significant memory immediately, was \(memoryIncrease) bytes"
        )

        print("Memory increase after eager RAG initialization: \(memoryIncrease) bytes")
    }

    @Test("Memory usage comparison between lazy and eager loading")
    func testMemoryUsageComparison() async throws {
        guard TestHelpers.isLocalModelAvailable else {
            return
        }
        let baseMemory: Int64 = getMemoryUsage()

        // Test lazy loading memory usage
        let lazyRag: Ragging = try await TestHelpers.createTestRag(database: .inMemory, loadingStrategy: .lazy)
        let lazyMemory: Int64 = getMemoryUsage()
        let lazyIncrease: Int64 = lazyMemory - baseMemory

        // Allow memory to stabilize
        try await Task.sleep(for: .milliseconds(100))

        // Test eager loading memory usage  
        let eagerRag: Ragging = try await TestHelpers.createTestRag(database: .inMemory, loadingStrategy: .eager)
        let eagerMemory: Int64 = getMemoryUsage()
        let eagerIncrease: Int64 = eagerMemory - lazyMemory

        // Eager should use significantly more memory than lazy
        #expect(eagerIncrease > lazyIncrease * 5, "Eager loading should use much more memory than lazy")

        print("Lazy loading memory increase: \(lazyIncrease) bytes")
        print("Eager loading additional memory increase: \(eagerIncrease) bytes")

        // Prevent optimization from removing variables
        _ = lazyRag
        _ = eagerRag
    }

    @Test("Memory usage after model loading is stable")
    func testMemoryStabilityAfterLoading() async throws {
        guard TestHelpers.isLocalModelAvailable else {
            return
        }
        let rag: Ragging = try await TestHelpers.createTestRag(database: .inMemory, loadingStrategy: .lazy)

        // Trigger model loading
        let content: String = "Test content for memory stability measurement."
        let fileURL: URL = try Self.createTextFile(with: content)

        for try await progress in await rag.add(fileURL: fileURL, id: UUID(), configuration: .default) {
            #expect(progress.completedUnitCount > 0)
        }

        let memoryAfterLoading: Int64 = getMemoryUsage()

        // Perform multiple operations
        for operationIndex in 0..<5 {
            let results: [SearchResult] = try await rag.semanticSearch(
                query: "test \(operationIndex)",
                numResults: 1,
                threshold: 10.0,
                table: "embeddings"
            )
            _ = results // Use the results to prevent optimization
        }

        let memoryAfterOperations: Int64 = getMemoryUsage()
        let memoryGrowth: Int64 = memoryAfterOperations - memoryAfterLoading

        // Memory should remain relatively stable (allow for some variance)
        #expect(
            memoryGrowth < 5_000_000,
            "Memory should remain stable after model loaded, growth was \(memoryGrowth) bytes"
        )

        print("Memory growth during operations: \(memoryGrowth) bytes")
    }

    // MARK: - Performance vs Memory Trade-off Tests

    @Test("First operation latency with lazy loading is acceptable")
    func testFirstOperationLatency() async throws {
        guard TestHelpers.isLocalModelAvailable else {
            return
        }
        let rag: Ragging = try await TestHelpers.createTestRag(database: .inMemory, loadingStrategy: .lazy)

        let content: String = "Test content for latency measurement."
        let fileURL: URL = try Self.createTextFile(with: content)

        let startTime: ContinuousClock.Instant = ContinuousClock.now

        // First operation should trigger model loading
        for try await progress in await rag.add(fileURL: fileURL, id: UUID(), configuration: .default) {
            #expect(progress.completedUnitCount > 0)
        }

        let duration: Duration = startTime.duration(to: .now)

        // First operation should complete within reasonable time (allowing for model loading)
        // Using 10 seconds as a generous threshold for CI environments
        #expect(duration < .seconds(10), "First operation with model loading took \(duration)")

        print("First operation with model loading took: \(duration)")
    }

    @Test("Subsequent operations have minimal latency")
    func testSubsequentOperationsLatency() async throws {
        guard TestHelpers.isLocalModelAvailable else {
            return
        }
        let rag: Ragging = try await TestHelpers.createTestRag(database: .inMemory, loadingStrategy: .lazy)

        // First operation to load model
        let content1: String = "Initial content to load the model."
        let fileURL1: URL = try Self.createTextFile(with: content1)

        for try await progress in await rag.add(fileURL: fileURL1, id: UUID(), configuration: .default) {
            #expect(progress.completedUnitCount > 0)
        }

        // Measure subsequent operation
        let content2: String = "Second content for latency measurement."
        let fileURL2: URL = try Self.createTextFile(with: content2)

        let startTime: ContinuousClock.Instant = ContinuousClock.now

        for try await progress in await rag.add(fileURL: fileURL2, id: UUID(), configuration: .default) {
            #expect(progress.completedUnitCount > 0)
        }

        let duration: Duration = startTime.duration(to: .now)

        // Subsequent operations should be fast (no model loading overhead)
        #expect(duration < .seconds(2), "Subsequent operation took \(duration)")

        print("Subsequent operation took: \(duration)")
    }
}
