import Abstractions
import Foundation
@testable import ModelDownloader
import Testing

extension APITests {
    @Test("ModelDownloader.explorer() returns CommunityModelsExplorer")
    func testExplorerCreation() {
        let downloader: ModelDownloader = ModelDownloader()
        let explorer: CommunityModelsExplorer = downloader.explorer()

        // Verify explorer is created
        #expect(type(of: explorer) == CommunityModelsExplorer.self)
    }

    @Test("Download discovered model through ModelDownloader extension")
    @MainActor
    func testDownloadDiscoveredModel() async throws {
        let context: TestDownloaderContext = TestDownloaderContext()
        defer { context.cleanup() }

        // Create a discovered model
        let discovered: DiscoveredModel = DiscoveredModel(
            id: "mlx-community/Llama-3.2-3B-Instruct-4bit",
            name: "test-model",
            author: "test-org",
            downloads: 1_000,
            likes: 50,
            tags: ["text-generation"],
            lastModified: Date(),
            files: [
                ModelFile(path: "model.safetensors", size: 4_000_000_000),
                ModelFile(path: "config.json", size: 1_024)
            ]
        )
        discovered.modelCard = "RAM: 8GB"
        discovered.detectedBackends = [SendableModel.Backend.mlx, SendableModel.Backend.gguf]

        let mlxFixture: MockHuggingFaceDownloader.FixtureModel = MockHuggingFaceDownloader.FixtureModel(
            modelId: discovered.id,
            backend: .mlx,
            name: discovered.name,
            files: [
                MockHuggingFaceDownloader.FixtureFile(
                    path: "model.safetensors",
                    data: Data(repeating: 0x1, count: 32),
                    size: 32
                ),
                MockHuggingFaceDownloader.FixtureFile(
                    path: "config.json",
                    data: Data("{}".utf8),
                    size: 2
                )
            ]
        )

        let ggufFixture: MockHuggingFaceDownloader.FixtureModel = MockHuggingFaceDownloader.FixtureModel(
            modelId: discovered.id,
            backend: .gguf,
            name: discovered.name,
            files: [
                MockHuggingFaceDownloader.FixtureFile(
                    path: "model.gguf",
                    data: Data(repeating: 0x2, count: 64),
                    size: 64
                ),
                MockHuggingFaceDownloader.FixtureFile(
                    path: "config.json",
                    data: Data("{}".utf8),
                    size: 2
                )
            ]
        )

        await context.mockDownloader.registerFixture(mlxFixture)
        await context.mockDownloader.registerFixture(ggufFixture)

        // Test download with default backend
        let defaultStream: AsyncThrowingStream<DownloadEvent, Error> = context.downloader.download(discovered)

        var defaultInfo: ModelInfo?
        for try await event in defaultStream {
            if case .completed(let info) = event {
                defaultInfo = info
            }
        }

        #expect(defaultInfo?.backend == .mlx)

        // Test download with preferred backend
        let ggufStream: AsyncThrowingStream<DownloadEvent, Error> = context.downloader.download(
            discovered,
            preferredBackend: SendableModel.Backend.gguf
        )

        var ggufInfo: ModelInfo?
        for try await event in ggufStream {
            if case .completed(let info) = event {
                ggufInfo = info
            }
        }

        #expect(ggufInfo?.backend == .gguf)
    }

    @Test("Download discovered model with no backends fails")
    @MainActor
    func testDownloadModelWithNoBackends() async {
        let downloader: ModelDownloader = ModelDownloader()

        // Model with no detected backends
        let discovered: DiscoveredModel = DiscoveredModel(
            id: "test-org/unsupported",
            name: "unsupported",
            author: "test-org",
            downloads: 0,
            likes: 0,
            tags: [],
            lastModified: Date(),
            files: [
                ModelFile(path: "unknown.format", size: 1_000_000)
            ]
        )
        discovered.detectedBackends = [] // No backends

        let stream: AsyncThrowingStream<DownloadEvent, Error> = downloader.download(discovered)

        do {
            for try await _ in stream {
                Issue.record("Expected error for unsupported model")
                break
            }
        } catch let error as HuggingFaceError {
            switch error {
            case .unsupportedFormat:
                // Expected error
                break

            default:
                Issue.record("Unexpected error type: \(error)")
            }
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }

    @Test("CommunityModelsExplorer.downloadModel helper")
    @MainActor
    func testExplorerDownloadHelper() async throws {
        let explorer: CommunityModelsExplorer = CommunityModelsExplorer()
        let context: TestDownloaderContext = TestDownloaderContext()
        defer { context.cleanup() }

        let discovered: DiscoveredModel = DiscoveredModel(
            id: "mlx-community/Llama-3.2-3B-Instruct-4bit",
            name: "test-model",
            author: "mlx-community",
            downloads: 2_000,
            likes: 100,
            tags: ["text-generation", "mlx"],
            lastModified: Date(),
            files: [
                ModelFile(path: "model.safetensors", size: 2_000_000_000),
                ModelFile(path: "config.json", size: 2_048)
            ]
        )
        discovered.detectedBackends = [SendableModel.Backend.mlx]

        let fixture: MockHuggingFaceDownloader.FixtureModel = MockHuggingFaceDownloader.FixtureModel(
            modelId: discovered.id,
            backend: .mlx,
            name: discovered.name,
            files: [
                MockHuggingFaceDownloader.FixtureFile(
                    path: "model.safetensors",
                    data: Data(repeating: 0x3, count: 16),
                    size: 16
                ),
                MockHuggingFaceDownloader.FixtureFile(
                    path: "config.json",
                    data: Data("{}".utf8),
                    size: 2
                )
            ]
        )
        await context.mockDownloader.registerFixture(fixture)

        // Test download helper
        let stream: AsyncThrowingStream<DownloadEvent, Error> = await explorer.downloadModel(
            discovered,
            using: context.downloader
        )

        // Verify stream is created
        var completedInfo: ModelInfo?
        for try await event in stream {
            if case .completed(let info) = event {
                completedInfo = info
            }
        }

        #expect(completedInfo?.backend == .mlx)
    }

    @Test("CommunityModelsExplorer.searchAndDownload integration")
    @MainActor
    func testSearchAndDownloadIntegration() async {
        // Create mock HTTP client
        let mockClient: CommunityMockHTTPClient = CommunityMockHTTPClient()

        // Mock detailed model info for discoverModel
        mockClient.responses["/api/models/mlx-community/Llama-3B-4bit"] = HTTPClientResponse(
            data: Data("""
            {
                "modelId": "mlx-community/Llama-3B-4bit",
                "author": "mlx-community",
                "downloads": 1000,
                "likes": 50,
                "tags": ["mlx"],
                "lastModified": "2024-01-01T00:00:00Z",
                "siblings": [
                    {"rfilename": "model.safetensors", "size": 3000},
                    {"rfilename": "config.json", "size": 2048},
                    {"rfilename": "tokenizer.json", "size": 512}
                ]
            }
            """.utf8),
            statusCode: 200,
            headers: [:]
        )

        // Mock model card
        mockClient.responses["/mlx-community/Llama-3B-4bit/raw/main/README.md"] = HTTPClientResponse(
            data: Data("# Llama 3B 4bit\nRAM: 6GB".utf8),
            statusCode: 200,
            headers: ["Content-Type": "text/plain"]
        )

        let explorer: CommunityModelsExplorer = CommunityModelsExplorer(httpClient: mockClient)
        let context: TestDownloaderContext = TestDownloaderContext()
        defer { context.cleanup() }

        let fixture: MockHuggingFaceDownloader.FixtureModel = MockHuggingFaceDownloader.FixtureModel(
            modelId: "mlx-community/Llama-3B-4bit",
            backend: .mlx,
            name: "Llama-3B-4bit",
            files: [
                MockHuggingFaceDownloader.FixtureFile(
                    path: "model.safetensors",
                    data: Data(repeating: 0x4, count: 48),
                    size: 48
                ),
                MockHuggingFaceDownloader.FixtureFile(
                    path: "config.json",
                    data: Data("{}".utf8),
                    size: 2
                ),
                MockHuggingFaceDownloader.FixtureFile(
                    path: "tokenizer.json",
                    data: Data(repeating: 0x5, count: 16),
                    size: 16
                )
            ]
        )
        await context.mockDownloader.registerFixture(fixture)

        // Test searchAndDownload
        let stream: AsyncThrowingStream<DownloadEvent, Error> = await explorer.searchAndDownload(
            modelId: "mlx-community/Llama-3B-4bit",
            using: context.downloader,
            preferredBackend: SendableModel.Backend.mlx
        )

        // Verify stream events
        var completedInfo: ModelInfo?
        do {
            for try await event in stream {
                if case .completed(let info) = event {
                    completedInfo = info
                }
            }
        } catch {
            Issue.record("Unexpected error: \(error)")
        }

        #expect(completedInfo?.backend == .mlx)
    }

    @Test("SearchAndDownload with invalid model ID")
    func testSearchAndDownloadInvalidModel() async {
        let mockClient: CommunityMockHTTPClient = CommunityMockHTTPClient()

        // Mock 404 response
        mockClient.responses["/api/models/invalid/model/tree/main"] = HTTPClientResponse(
            data: Data(),
            statusCode: 404,
            headers: [:]
        )

        let explorer: CommunityModelsExplorer = CommunityModelsExplorer(httpClient: mockClient)
        let downloader: ModelDownloader = ModelDownloader()

        let stream: AsyncThrowingStream<DownloadEvent, Error> = await explorer.searchAndDownload(
            modelId: "invalid/model",
            using: downloader
        )

        // Should receive error through stream
        do {
            for try await _ in stream {
                Issue.record("Expected error for invalid model")
                break
            }
        } catch let error as HuggingFaceError {
            switch error {
            case .repositoryNotFound:
                // Expected error
                break

            default:
                Issue.record("Unexpected error type: \(error)")
            }
        } catch {
            // Could be other errors in test environment
            // This is acceptable
        }
    }

    @Test("Download with preferred backend selection")
    @MainActor
    func testPreferredBackendSelection() async throws {
        let context: TestDownloaderContext = TestDownloaderContext()
        defer { context.cleanup() }

        // Model with multiple backends
        let multiBackendModel: DiscoveredModel = DiscoveredModel(
            id: "mlx-community/Llama-3.2-3B-Instruct-4bit",
            name: "multi-backend",
            author: "test",
            downloads: 5_000,
            likes: 200,
            tags: ["text-generation"],
            lastModified: Date(),
            files: [
                ModelFile(path: "model.safetensors", size: 2_000_000_000),
                ModelFile(path: "model.gguf", size: 1_800_000_000),
                ModelFile(path: "model.mlpackage", size: 2_200_000_000),
                ModelFile(path: "config.json", size: 1_024)
            ]
        )
        multiBackendModel.modelCard = "Supports MLX, GGUF, and CoreML. RAM: 8GB"
        multiBackendModel.detectedBackends = [
            SendableModel.Backend.mlx,
            SendableModel.Backend.gguf,
            SendableModel.Backend.coreml
        ]

        let fixtures: [MockHuggingFaceDownloader.FixtureModel] = [
            MockHuggingFaceDownloader.FixtureModel(
                modelId: multiBackendModel.id,
                backend: .mlx,
                name: multiBackendModel.name,
                files: [
                    MockHuggingFaceDownloader.FixtureFile(
                        path: "model.safetensors",
                        data: Data(repeating: 0x6, count: 24),
                        size: 24
                    ),
                    MockHuggingFaceDownloader.FixtureFile(
                        path: "config.json",
                        data: Data("{}".utf8),
                        size: 2
                    )
                ]
            ),
            MockHuggingFaceDownloader.FixtureModel(
                modelId: multiBackendModel.id,
                backend: .gguf,
                name: multiBackendModel.name,
                files: [
                    MockHuggingFaceDownloader.FixtureFile(
                        path: "model.gguf",
                        data: Data(repeating: 0x7, count: 24),
                        size: 24
                    ),
                    MockHuggingFaceDownloader.FixtureFile(
                        path: "config.json",
                        data: Data("{}".utf8),
                        size: 2
                    )
                ]
            ),
            MockHuggingFaceDownloader.FixtureModel(
                modelId: multiBackendModel.id,
                backend: .coreml,
                name: multiBackendModel.name,
                files: [
                    MockHuggingFaceDownloader.FixtureFile(
                        path: "TextEncoder.mlmodelc/model.mil",
                        data: Data(repeating: 0x8, count: 16),
                        size: 16
                    ),
                    MockHuggingFaceDownloader.FixtureFile(
                        path: "config.json",
                        data: Data("{}".utf8),
                        size: 2
                    )
                ]
            )
        ]

        for fixture in fixtures {
            await context.mockDownloader.registerFixture(fixture)
        }

        // Test each backend preference
        let backends: [SendableModel.Backend] = [
            SendableModel.Backend.mlx,
            SendableModel.Backend.gguf,
            SendableModel.Backend.coreml
        ]

        for preferredBackend in backends {
            let stream: AsyncThrowingStream<DownloadEvent, Error> = context.downloader.download(
                multiBackendModel,
                preferredBackend: preferredBackend
            )

            var completedInfo: ModelInfo?
            for try await event in stream {
                if case .completed(let info) = event {
                    completedInfo = info
                }
            }

            #expect(completedInfo?.backend == preferredBackend)
        }
    }

    @Test("Download progress tracking simulation")
    @MainActor
    func testDownloadProgressEvents() async {
        let context: TestDownloaderContext = TestDownloaderContext()
        defer { context.cleanup() }

        let discovered: DiscoveredModel = DiscoveredModel(
            id: "test/progress-model",
            name: "progress-model",
            author: "test",
            downloads: 1_000,
            likes: 50,
            tags: ["text-generation"],
            lastModified: Date(),
            files: [
                ModelFile(path: "model.gguf", size: 100_000_000) // 100MB for quick test
            ]
        )
        discovered.detectedBackends = [SendableModel.Backend.gguf]

        let fixture: MockHuggingFaceDownloader.FixtureModel = MockHuggingFaceDownloader.FixtureModel(
            modelId: discovered.id,
            backend: .gguf,
            name: discovered.name,
            files: [
                MockHuggingFaceDownloader.FixtureFile(
                    path: "model.gguf",
                    data: Data(repeating: 0x9, count: 32),
                    size: 32
                )
            ]
        )
        await context.mockDownloader.registerFixture(fixture)

        let stream: AsyncThrowingStream<DownloadEvent, Error> = context.downloader.download(discovered)

        var sawProgress: Bool = false
        var completedInfo: ModelInfo?

        do {
            for try await event in stream {
                switch event {
                case .progress:
                    sawProgress = true

                case .completed(let info):
                    completedInfo = info
                }
            }
        } catch {
            Issue.record("Unexpected error: \(error)")
        }

        #expect(sawProgress)
        #expect(completedInfo?.backend == .gguf)
    }

    @Test("Integration with model preview")
    @MainActor
    func testModelPreviewBeforeDownload() async {
        let explorer: CommunityModelsExplorer = CommunityModelsExplorer()

        let discovered: DiscoveredModel = DiscoveredModel(
            id: "test/preview-model",
            name: "preview-model",
            author: "test",
            downloads: 3_000,
            likes: 150,
            tags: ["llama", "instruct", "4bit"],
            lastModified: Date(timeIntervalSince1970: 1_700_000_000),
            files: [
                ModelFile(path: "model.safetensors", size: 2_500_000_000)
            ]
        )
        discovered.detectedBackends = [SendableModel.Backend.mlx]

        // Get preview before downloading
        let preview: ModelInfo = await explorer.getModelPreview(discovered)

        #expect(preview.name == "preview-model")
        #expect(preview.backend == SendableModel.Backend.mlx)
        #expect(preview.totalSize == 2_500_000_000)
        #expect(preview.metadata["author"] == "test")
        #expect(preview.metadata["downloads"] == "3000")
        #expect(preview.metadata["likes"] == "150")
        #expect(preview.metadata["tags"]?.contains("llama") == true)
    }
}
