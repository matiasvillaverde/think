import Abstractions
import Foundation
import ModelDownloader
import Testing

/// Test to verify CoreML model download functionality with detailed output
@Suite("CoreML Download Verification")
struct CoreMLDownloadTest {
    @Test(
        "Verify CoreML download from animagine-xl-3.1 repo",
        .timeLimit(.minutes(5)),
        .disabled("This test are to be run only before releasing the app")
    )
    func testCoreMLAnimagineDownload() async throws {
        let downloader: ModelDownloader = ModelDownloader.shared

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
            backend: SendableModel.Backend.coreml
        )

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

        // Verify we got exactly one ZIP file (smart selection)
        let zipFiles: [String] = downloadedFiles.filter { $0.hasSuffix(".zip") }
        print("\nSmart Selection Results:")
        print("   ZIP files downloaded: \(zipFiles.count)")
        #expect(zipFiles.count == 1, "Should download exactly one ZIP file")

        if let selectedZip = zipFiles.first {
            print("   Selected: \(selectedZip)")

            // Verify it's from a subdirectory
            #expect(selectedZip.contains("/"), "ZIP file should be from a subdirectory")

            // Verify smart selection chose 768x768 if available
            if selectedZip.contains("768x768") {
                print("   ✓ Optimal resolution selected (768x768)")
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

        // Clean up  
        try await downloader.deleteModel(model: sendableModel.location)
        print("\n🧹 Cleaned up: Model deleted after test")
    }

    private func extractResolution(from path: String) -> String? {
        let pattern: String = #"(\d{3,4})x(\d{3,4})"#

        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: path, range: NSRange(path.startIndex..., in: path)) else {
            return nil
        }

        return String(path[Range(match.range, in: path)!])
    }
}
