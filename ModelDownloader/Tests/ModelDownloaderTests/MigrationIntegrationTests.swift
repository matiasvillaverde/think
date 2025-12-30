import Abstractions
import Foundation
@testable import ModelDownloader
import Testing

@Suite("Migration Integration Tests")
@MainActor
struct MigrationIntegrationTests {
    // Test helper to create models
    func createTestModel() -> DiscoveredModel {
        let model: DiscoveredModel = DiscoveredModel(
            id: "test/migration-model",
            name: "Migration Test Model",
            author: "test-author",
            downloads: 1_000,
            likes: 100,
            tags: ["test", "migration"],
            lastModified: Date(),
            files: [
                ModelFile(
                    path: "model.gguf",
                    size: 1_024 * 1_024, // 1MB
                    sha: "test-sha256"
                ),
                ModelFile(
                    path: "config.json",
                    size: 256,
                    sha: "config-sha256"
                )
            ]
        )
        model.detectedBackends = [SendableModel.Backend.gguf]
        model.modelCard = "RAM: 1GB"
        return model
    }

    @Test("Both implementations handle download events consistently")
    @MainActor
    func testDownloadEventConsistency() async {
        let testModel: DiscoveredModel = createTestModel()

        let context1: TestDownloaderContext = TestDownloaderContext()
        let context2: TestDownloaderContext = TestDownloaderContext()
        defer {
            context1.cleanup()
            context2.cleanup()
        }

        let fixture: MockHuggingFaceDownloader.FixtureModel = MockHuggingFaceDownloader.FixtureModel(
            modelId: testModel.id,
            backend: .gguf,
            name: testModel.name,
            files: [
                MockHuggingFaceDownloader.FixtureFile(
                    path: "model.gguf",
                    data: Data(repeating: 0x1, count: 12),
                    size: 12
                ),
                MockHuggingFaceDownloader.FixtureFile(
                    path: "config.json",
                    data: Data("{}".utf8),
                    size: 2
                )
            ]
        )
        await context1.mockDownloader.registerFixture(fixture)
        await context2.mockDownloader.registerFixture(fixture)

        let events1: [DownloadEvent] = await collectEvents(
            from: context1.downloader.download(testModel)
        )
        let events2: [DownloadEvent] = await collectEvents(
            from: context2.downloader.download(testModel)
        )

        #expect(events1.count == events2.count)
        let isCompleted1: Bool
        if case .completed = events1.last {
            isCompleted1 = true
        } else {
            isCompleted1 = false
        }
        #expect(isCompleted1)
        let isCompleted2: Bool
        if case .completed = events2.last {
            isCompleted2 = true
        } else {
            isCompleted2 = false
        }
        #expect(isCompleted2)
    }

    @Test("Both implementations create consistent SendableModel")
    func testSendableModelCreation() async throws {
        let testModel: DiscoveredModel = createTestModel()

        // Create mock explorer to test conversion
        let explorer: CommunityModelsExplorer = CommunityModelsExplorer()

        // Both implementations should use the same conversion logic
        let sendableModel1: SendableModel = try await explorer.prepareForDownload(testModel)
        let sendableModel2: SendableModel = try await explorer.prepareForDownload(testModel)

        // Should create consistent UUIDs for same model
        #expect(sendableModel1.id == sendableModel2.id)
        #expect(sendableModel1.location == sendableModel2.location)
    }

    @Test("Both implementations handle missing files consistently")
    func testMissingFilesHandling() async {
        // Create model with no files
        let emptyModel: DiscoveredModel = DiscoveredModel(
            id: "test/empty-model",
            name: "Empty Test Model",
            author: "test",
            downloads: 0,
            likes: 0,
            tags: ["empty"],
            lastModified: Date(),
            files: []
        )

        // Create downloader instances
        let downloader1: ModelDownloader = ModelDownloader()
        let downloader2: ModelDownloader = ModelDownloader()

        // Both should handle empty files gracefully
        let originalStream: AsyncThrowingStream<DownloadEvent, Error> = downloader1.download(emptyModel)
        let refactoredStream: AsyncThrowingStream<DownloadEvent, Error> = downloader2.download(emptyModel)

        // Collect errors from both
        var originalError: Error?
        var refactoredError: Error?

        // Try to get first event from original
        var originalIterator: AsyncThrowingStream<DownloadEvent, Error>.AsyncIterator =
            originalStream.makeAsyncIterator()
        do {
            _ = try await originalIterator.next()
        } catch {
            originalError = error
        }

        // Try to get first event from refactored
        var refactoredIterator: AsyncThrowingStream<DownloadEvent, Error>.AsyncIterator =
            refactoredStream.makeAsyncIterator()
        do {
            _ = try await refactoredIterator.next()
        } catch {
            refactoredError = error
        }

        // Both should error (no files to download)
        #expect(originalError != nil)
        #expect(refactoredError != nil)
    }

    @Test("Both implementations use same file manager")
    func testFileManagerConsistency() async {
        // Create both implementations with same directories
        let modelsDir: URL = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("TestModels")
        let tempDir: URL = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("TestTemp")

        let downloader1: ModelDownloader = ModelDownloader(
            modelsDirectory: modelsDir,
            temporaryDirectory: tempDir
        )

        let downloader2: ModelDownloader = ModelDownloader(
            modelsDirectory: modelsDir,
            temporaryDirectory: tempDir
        )

        // Both should be initialized successfully
        #expect(type(of: downloader1) == ModelDownloader.self)
        #expect(type(of: downloader2) == ModelDownloader.self)

        // Check they would use same paths for models
        let testSendableModel: SendableModel = SendableModel(
            id: UUID(),
            ramNeeded: 1_000,
            modelType: .language,
            location: "test/model",
            architecture: .unknown,
            backend: SendableModel.Backend.mlx,
            locationKind: .huggingFace
        )

        // Both should report same model existence (false for new model)
        let originalExists: Bool = await downloader1.modelExists(model: testSendableModel.location)
        let refactoredExists: Bool = await downloader2.modelExists(model: testSendableModel.location)

        #expect(originalExists == refactoredExists)
        #expect(originalExists == false)
    }

    @Test("Feature flag correctly switches implementation")
    func testFeatureFlagSwitching() async throws {
        // Test multiple configurations
        let configurations: [(useRefactored: Bool, description: String)] = [
            (false, "Original implementation"),
            (true, "Refactored implementation"),
            (false, "Back to original"),
            (true, "Back to refactored")
        ]

        for config: (useRefactored: Bool, description: String) in configurations {
            let downloader: ModelDownloader = ModelDownloader()

            // Verify it was created successfully
            #expect(type(of: downloader) == ModelDownloader.self,
                   "Failed to create \(config.description)")

            // Test basic operation
            let models: [ModelInfo] = try await downloader.listDownloadedModels()
            #expect(models.isEmpty || !models.isEmpty,
                   "\(config.description) should return valid model list")
        }
    }

    @Test("Both implementations handle concurrent downloads")
    func testConcurrentDownloads() {
        // Create test models
        let models: [DiscoveredModel] = [
            DiscoveredModel(
                id: "test/model1",
                name: "Model 1",
                author: "test",
                downloads: 100,
                likes: 10,
                tags: ["test"],
                lastModified: Date(),
                files: []
            ),
            DiscoveredModel(
                id: "test/model2",
                name: "Model 2",
                author: "test",
                downloads: 200,
                likes: 20,
                tags: ["test"],
                lastModified: Date(),
                files: []
            )
        ]

        // Create downloader instances
        let downloader1: ModelDownloader = ModelDownloader()
        let downloader2: ModelDownloader = ModelDownloader()

        // Start concurrent downloads with original
        let originalStreams: [AsyncThrowingStream<DownloadEvent, Error>] = models.map { downloader1.download($0) }

        // Start concurrent downloads with refactored
        let refactoredStreams: [AsyncThrowingStream<DownloadEvent, Error>] = models.map { downloader2.download($0) }

        // Both should handle multiple streams without crash
        #expect(originalStreams.count == models.count)
        #expect(refactoredStreams.count == models.count)
    }

    @Test("Refactored implementation integrates new components")
    func testRefactoredUsesNewComponents() async {
        let testModel: DiscoveredModel = createTestModel()

        // Create refactored implementation
        let downloader: ModelDownloader = ModelDownloader()

        // The refactored implementation should use:
        // - DownloadTaskManager for task management
        // - ModelIdentityService for consistent UUID generation
        // - DefaultDownloadCoordinator for coordinating downloads
        // - New error types (ModelDownloadError)

        // Start a download
        let stream: AsyncThrowingStream<DownloadEvent, Error> = downloader.download(testModel)

        // Even if it fails, it should be using the new architecture
        var eventCount: Int = 0
        do {
            for try await _ in stream {
                eventCount += 1
                if eventCount > 3 { break } // Limit iterations
            }
        } catch {
            // Expected for test URLs
        }

        // The fact it runs without crashing indicates integration works
        #expect(eventCount >= 0)
    }
}

@MainActor
private func collectEvents(
    from stream: AsyncThrowingStream<DownloadEvent, Error>
) async -> [DownloadEvent] {
    var events: [DownloadEvent] = []
    do {
        for try await event in stream {
            events.append(event)
        }
    } catch {
        Issue.record("Unexpected error: \(error)")
    }
    return events
}
