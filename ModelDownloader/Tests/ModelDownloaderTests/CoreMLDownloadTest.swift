import Abstractions
import Foundation
@testable import ModelDownloader
import Testing

/// Test to verify CoreML model download functionality with detailed output
@Suite("CoreML Download Verification")
struct CoreMLDownloadTest {
    @Test("Verify CoreML download from animagine-xl-3.1 repo")
    @MainActor
    func testCoreMLAnimagineDownload() async throws {
        let context: TestDownloaderContext = TestDownloaderContext()
        defer { context.cleanup() }
        let downloader: ModelDownloader = context.downloader

        print("\nStarting CoreML download test for animagine-xl-3.1...")
        print("Repository: coreml-community/coreml-animagine-xl-3.1")
        print("Expected structure: split-einsum/<resolution>/*.zip files")

        actor ProgressTracker {
            private var downloadedFiles: [String] = []
            private var lastProgress: Double = 0

            func addFile(_ fileName: String) {
                if !downloadedFiles.contains(fileName) {
                    downloadedFiles.append(fileName)
                }
            }

            func updateProgress(_ progress: Double) {
                lastProgress = progress
            }

            func getFiles() -> [String] {
                downloadedFiles
            }
        }

        let tracker: ProgressTracker = ProgressTracker()

        // Download the model
        let sendableModel: SendableModel = SendableModel(
            id: UUID(),
            ramNeeded: 1_073_741_824, // 1GB
            modelType: .diffusion,
            location: "coreml-community/coreml-animagine-xl-3.1",
            architecture: .stableDiffusion,
            backend: SendableModel.Backend.coreml,
            locationKind: .huggingFace
        )

        let fixture: MockHuggingFaceDownloader.FixtureModel = MockHuggingFaceDownloader.FixtureModel(
            modelId: sendableModel.location,
            backend: .coreml,
            name: sendableModel.location,
            files: [
                MockHuggingFaceDownloader.FixtureFile(
                    path: "TextEncoder.mlmodelc/model.mil",
                    data: Data(repeating: 0x1, count: 64),
                    size: 64
                ),
                MockHuggingFaceDownloader.FixtureFile(
                    path: "merges.txt",
                    data: Data("merge".utf8),
                    size: Int64("merge".utf8.count)
                ),
                MockHuggingFaceDownloader.FixtureFile(
                    path: "vocab.json",
                    data: Data("{\"vocab\":true}".utf8),
                    size: Int64("{\"vocab\":true}".utf8.count)
                ),
                MockHuggingFaceDownloader.FixtureFile(
                    path: "model_info.json",
                    data: Data("{\"info\":true}".utf8),
                    size: Int64("{\"info\":true}".utf8.count)
                )
            ]
        )
        await context.mockDownloader.registerFixture(fixture)

        var modelInfo: ModelInfo?

        for try await event in downloader.downloadModel(sendableModel: sendableModel) {
            switch event {
            case .progress(let progress):
                // Track progress
                if let fileName = progress.currentFileName {
                    Task {
                        await tracker.addFile(fileName)
                    }
                }

                let mbDownloaded: Double = Double(progress.bytesDownloaded) / 1_000_000
                let mbTotal: Double = Double(progress.totalBytes) / 1_000_000

                print(
                    String(
                        format: "[%d/%d] %@ - %.1f/%.1f MB (%d%%)",
                        progress.filesCompleted,
                        progress.totalFiles,
                        progress.currentFileName ?? "Unknown",
                        mbDownloaded,
                        mbTotal,
                        Int(progress.percentage)
                    )
                )

                Task {
                    await tracker.updateProgress(progress.percentage)
                }

            case .completed(let info):
                modelInfo = info
            }
        }

        guard let modelInfo else {
            throw ModelDownloadError.repositoryNotFound("coreml-community/coreml-animagine-xl-3.1")
        }

        // Get tracked files
        let downloadedFiles: [String] = await tracker.getFiles()

        // Print detailed results
        print("\nCoreML Model Download Complete!")
        print("Download Summary:")
        print("   Model: \(modelInfo.name)")
        print("   Backend: \(modelInfo.backend)")
        print("   Location: \(modelInfo.location.path)")
        print("   Total Size: \(modelInfo.totalSize / 1_000_000) MB")
        print("   Files Downloaded: \(downloadedFiles.count)")

        print("\n📁 Downloaded Files:")
        for (index, file) in downloadedFiles.enumerated() {
            print("   \(index + 1). \(file)")

            // Check if it's from subdirectory
            if file.contains("split-einsum/") || file.contains("split_einsum/") {
                print("      ✓ Correctly downloaded from subdirectory")
            }

            // Check resolution if present
            if let resolution = extractResolution(from: file) {
                print("      ✓ Resolution: \(resolution)")
            }
        }

        // List actual directory contents
        print("\n📂 Model Directory Contents:")
        let fileManager: FileManager = FileManager.default
        if let contents = try? fileManager.contentsOfDirectory(
            at: modelInfo.location,
            includingPropertiesForKeys: [URLResourceKey.fileSizeKey]
        ) {
            for file in contents {
                let attributes: URLResourceValues? = try? file.resourceValues(forKeys: [URLResourceKey.fileSizeKey])
                let size: Int = attributes?.fileSize ?? 0
                print("   - \(file.lastPathComponent) (\(size / 1_000_000) MB)")
            }
        }

        // Verify expectations
        #expect(modelInfo.backend == SendableModel.Backend.coreml)
        #expect(modelInfo.totalSize > 0)
        let contents: [URL] = try fileManager.contentsOfDirectory(
            at: modelInfo.location,
            includingPropertiesForKeys: nil
        )
        let mlmodelcDirs: [URL] = contents.filter { $0.pathExtension == "mlmodelc" }
        #expect(!mlmodelcDirs.isEmpty)

        // Clean up  
        try await downloader.deleteModel(model: sendableModel.location)
        print("\n🧹 Cleaned up: Model deleted after test")
    }
}

private func extractResolution(from path: String) -> String? {
    let components: [String] = path.split(separator: "/").map(String.init)
    guard let markerIndex = components.firstIndex(where: { component in
        component == "split-einsum" || component == "split_einsum"
    }) else {
        return nil
    }

    let resolutionIndex: Int = components.index(after: markerIndex)
    guard resolutionIndex < components.count else {
        return nil
    }

    return components[resolutionIndex]
}
