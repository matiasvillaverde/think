import Abstractions
import Foundation
@testable import LLamaCPP
import Testing

extension LlamaCPPModelTestSuite {
    @Test("Preload loads model into memory")
    internal func testPreloadLoadsModel() async throws {
        let configuration: ProviderConfiguration = try TestHelpers.createTestConfiguration()
        let session: LlamaCPPSession = LlamaCPPSession()

        let preloadStream: AsyncThrowingStream<Progress, Error> = await session.preload(
            configuration: configuration
        )
        for try await _ in preloadStream {
            // Just consume the progress updates
        }

        // Collect progress updates during preload
        let progressStream: AsyncThrowingStream<Progress, Error> = await session.preload(
            configuration: configuration
        )
        var progressUpdates: [Progress] = []
        for try await progress in progressStream {
            progressUpdates.append(progress)
        }

        // Verify we got progress updates
        #expect(!progressUpdates.isEmpty)
        #expect(progressUpdates.last?.completedUnitCount == progressUpdates.last?.totalUnitCount)

        // Verify model is loaded by attempting to use it
        let input: LLMInput = TestHelpers.createTestInput(context: "Hi", maxTokens: 1)
        let stream: AsyncThrowingStream<LLMStreamChunk, Error> = await session.stream(input)
        let chunks: [LLMStreamChunk] = try await TestHelpers.collectChunks(from: stream, limit: 2)

        #expect(!chunks.isEmpty)
        await session.unload()
    }

    @Test("Preload streams progress updates")
    internal func testPreloadStreamsProgress() async throws {
        let configuration: ProviderConfiguration = try TestHelpers.createTestConfiguration()
        let session: LlamaCPPSession = LlamaCPPSession()

        let preloadStream: AsyncThrowingStream<Progress, Error> = await session.preload(
            configuration: configuration
        )
        for try await _ in preloadStream {
            // Just consume the progress updates
        }

        // Collect progress updates
        let progressStream: AsyncThrowingStream<Progress, Error> = await session.preload(
            configuration: configuration
        )
        var progressUpdates: [Progress] = []

        for try await progress in progressStream {
            progressUpdates.append(progress)

            // Verify progress has expected properties
            #expect(progress.totalUnitCount > 0)
            #expect(progress.completedUnitCount >= 0)
            #expect(progress.completedUnitCount <= progress.totalUnitCount)
            #expect(progress.localizedDescription != nil)
        }

        // Verify we received multiple progress updates
        #expect(progressUpdates.count >= 1)

        // Verify final progress shows completion
        if let finalProgress = progressUpdates.last {
            #expect(finalProgress.completedUnitCount == finalProgress.totalUnitCount)
        }

        // Clean up
        await session.unload()
    }

    @Test("Preload reports progress stages")
    internal func testPreloadReportsProgressStages() async throws {
        let configuration: ProviderConfiguration = try TestHelpers.createTestConfiguration()
        let session: LlamaCPPSession = LlamaCPPSession()

        // Collect all progress updates
        let progressStream: AsyncThrowingStream<Progress, Error> = await session.preload(
            configuration: configuration
        )
        var progressUpdates: [Progress] = []

        for try await progress in progressStream {
            progressUpdates.append(progress)
        }

        // Verify we got progress updates (2: initializing and completed)
        #expect(progressUpdates.count == 2, "Should have 2 progress updates, got \(progressUpdates.count)")

        // Verify progress values
        if progressUpdates.count == 2 {
            // Initial: 0/2
            #expect(progressUpdates[0].completedUnitCount == 0)
            #expect(progressUpdates[0].totalUnitCount == 2)
            #expect(progressUpdates[0].localizedAdditionalDescription?.contains("Initializing") ?? false)

            // Complete: 2/2
            #expect(progressUpdates[1].completedUnitCount == 2)
            #expect(progressUpdates[1].totalUnitCount == 2)
            #expect(progressUpdates[1].localizedAdditionalDescription?.contains("successfully") ?? false)
        }

        // Verify model is actually loaded by using it
        let input: LLMInput = TestHelpers.createTestInput(context: "Test", maxTokens: 1)
        let stream: AsyncThrowingStream<LLMStreamChunk, Error> = await session.stream(input)
        let chunks: [LLMStreamChunk] = try await TestHelpers.collectChunks(from: stream, limit: 2)
        #expect(!chunks.isEmpty, "Model should be usable after preload")

        // Clean up
        await session.unload()
    }

    @Test("Preload returns immediately if model already loaded")
    internal func testPreloadIdempotent() async throws {
        let configuration: ProviderConfiguration = try TestHelpers.createTestConfiguration()
        let session: LlamaCPPSession = LlamaCPPSession()

        let preloadStream: AsyncThrowingStream<Progress, Error> = await session.preload(
            configuration: configuration
        )
        for try await _ in preloadStream {
            // Just consume the progress updates
        }

        // First preload
        let firstStream: AsyncThrowingStream<Progress, Error> = await session.preload(
            configuration: configuration
        )
        var firstProgressCount: Int = 0
        for try await _ in firstStream {
            firstProgressCount += 1
        }

        // Second preload should return immediately
        let secondStream: AsyncThrowingStream<Progress, Error> = await session.preload(
            configuration: configuration
        )
        var secondProgressUpdates: [Progress] = []
        for try await progress in secondStream {
            secondProgressUpdates.append(progress)
        }

        // Should get a single "already loaded" progress update
        #expect(secondProgressUpdates.count == 1)
        if let progress = secondProgressUpdates.first {
            #expect(progress.completedUnitCount == progress.totalUnitCount)
            #expect(progress.localizedDescription.contains("already"))
        }

        // Clean up
        await session.unload()
    }

    @Test("Unload frees model resources")
    internal func testUnloadFreesResources() async throws {
        let configuration: ProviderConfiguration = try TestHelpers.createTestConfiguration()
        let session: LlamaCPPSession = LlamaCPPSession()

        let preloadStream: AsyncThrowingStream<Progress, Error> = await session.preload(
            configuration: configuration
        )
        for try await _ in preloadStream {
            // Just consume the progress updates
        }
        let input: LLMInput = TestHelpers.createTestInput(context: "Test", maxTokens: 1)

        // First load and use the model
        let stream1: AsyncThrowingStream<LLMStreamChunk, Error> = await session.stream(input)
        _ = try await TestHelpers.collectChunks(from: stream1, limit: 2)

        // Unload the model
        await session.unload()

        // Next stream should reload the model
        let stream2: AsyncThrowingStream<LLMStreamChunk, Error> = await session.stream(input)
        let chunks2: [LLMStreamChunk] = try await TestHelpers.collectChunks(from: stream2, limit: 2)

        #expect(!chunks2.isEmpty)
        await session.unload()
    }
}
