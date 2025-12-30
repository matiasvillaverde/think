import Abstractions
import Foundation
@testable import ModelDownloader
import Testing

/// Documentation tests demonstrating proper usage of the ModelDownloader public API.
/// These tests are disabled by default as they download real models from HuggingFace.
/// Enable them manually to verify the examples work correctly.
///
/// IMPORTANT: These tests use only the public API - no @testable imports.
/// They serve as copy-paste documentation for package users.
///
/// NOTE: All download tests automatically clean up by deleting the downloaded models
/// after verification to avoid consuming disk space.

private enum PublicAPITestError: Error {
    case downloadDidNotComplete
}

extension APITests {
    // MARK: - Helper Methods

    /// Helper function to recursively list files in a directory
    private func listFiles(at url: URL, indent: String = "   ") {
        let fileManager: FileManager = FileManager.default
        do {
            let resourceKeys: [URLResourceKey] = [.isDirectoryKey, .fileSizeKey]
            let contents: [URL] = try fileManager.contentsOfDirectory(
                at: url,
                includingPropertiesForKeys: resourceKeys,
                options: [.skipsHiddenFiles]
            )

            for item: URL in contents.sorted(by: { $0.lastPathComponent < $1.lastPathComponent }) {
                let resources: URLResourceValues = try item.resourceValues(forKeys: Set(resourceKeys))
                let isDirectory: Bool = resources.isDirectory ?? false
                let fileSize: Int = resources.fileSize ?? 0

                if isDirectory {
                    print("\(indent)\(item.lastPathComponent)/")
                    // Recursively list contents of subdirectory
                    listFiles(at: item, indent: indent + "   ")
                } else {
                    let sizeMB: Double = Double(fileSize) / 1_000_000
                    print("\(indent)\(item.lastPathComponent) (\(String(format: "%.1f", sizeMB)) MB)")
                }
            }
        } catch {
            print("\(indent)Error listing contents: \(error)")
        }
    }

    // MARK: - Basic Download Examples

    /// Demonstrates how to download an MLX format model.
    /// MLX models typically include safetensors files and configuration.
    @Test("Download MLX model using public API")
    @MainActor
    func downloadMLXModel() async throws {
        let context: TestDownloaderContext = TestDownloaderContext()
        defer { context.cleanup() }
        let downloader: ModelDownloader = context.downloader

        // Create a SendableModel for downloading
        let sendableModel: SendableModel = SendableModel(
            id: UUID(),
            ramNeeded: 1_073_741_824, // 1GB
            modelType: .language,
            location: "mlx-community/Llama-3.2-1B-Instruct-4bit",
            architecture: .llama,
            backend: SendableModel.Backend.mlx,
            locationKind: .huggingFace
        )

        let totalSize: Int64 = await registerMLXFixture(
            in: context,
            modelId: sendableModel.location,
            name: sendableModel.location
        )

        // Download the model using AsyncThrowingStream
        var modelInfo: ModelInfo?

        for try await event: DownloadEvent in downloader.downloadModel(sendableModel: sendableModel) {
            switch event {
            case .progress(let progress):
                // Progress event is received periodically during download
                print("[\(progress.filesCompleted)/\(progress.totalFiles)] " +
                      "\(progress.currentFileName ?? "Preparing...") - " +
                      "\(Int(progress.percentage))%")

            case .completed(let info):
                // Download completed successfully
                modelInfo = info
                print("Download completed")
            }
        }

        // Verify the download completed successfully
        guard let modelInfo: ModelInfo else {
            throw PublicAPITestError.downloadDidNotComplete
        }

        #expect(modelInfo.backend == SendableModel.Backend.mlx)
        #expect(modelInfo.location.path.contains("mlx"))
        #expect(modelInfo.totalSize == totalSize)

        print("Downloaded: \(modelInfo.name)")
        print("   Location: \(modelInfo.location)")
        print("   Size: \(modelInfo.totalSize) bytes")
        print("   ID: \(modelInfo.id)")
        print("   path: \(modelInfo.location.path)")

        // List the actual files in the model directory recursively
        print("\n📂 Model Directory Contents:")
        listFiles(at: modelInfo.location)

        // Validate files
        try validateMLXModelStructure(at: modelInfo.location)

        // Clean up: Delete the downloaded model to save disk space
        try await downloader.deleteModel(model: sendableModel.location)
        print("🧹 Cleaned up: Model deleted after test")
    }

    /// Demonstrates how to download a GGUF format model.
    /// GGUF models use smart selection based on available device memory.
    @Test("Download GGUF model with automatic memory-based selection")
    @MainActor
    func downloadGGUFModel() async throws {
        let context: TestDownloaderContext = TestDownloaderContext()
        defer { context.cleanup() }
        let downloader: ModelDownloader = context.downloader

        // Create a SendableModel for GGUF format
        let sendableModel: SendableModel = SendableModel(
            id: UUID(),
            ramNeeded: 600_000_000, // 600MB
            modelType: .language,
            location: "unsloth/Qwen3-0.6B-GGUF",
            architecture: .qwen,
            backend: SendableModel.Backend.gguf,
            locationKind: .huggingFace
        )

        let totalSize: Int64 = await registerGGUFFixture(
            in: context,
            modelId: sendableModel.location,
            name: sendableModel.location
        )

        // The downloader automatically selects the best GGUF file based on device memory
        var modelInfo: ModelInfo?

        for try await event: DownloadEvent in downloader.downloadModel(sendableModel: sendableModel) {
            switch event {
            case .progress(let progress):
                // Track download progress
                let percentage: Int = Int(progress.percentage)
                let currentFile: String = progress.currentFileName ?? "Initializing"
                print("Downloading: \(currentFile) [\(percentage)%]")

            case .completed(let info):
                modelInfo = info
                print("Download completed")
            }
        }

        // Verify GGUF format was downloaded
        guard let modelInfo: ModelInfo else {
            throw PublicAPITestError.downloadDidNotComplete
        }

        #expect(modelInfo.backend == SendableModel.Backend.gguf)
        #expect(modelInfo.location.path.contains("gguf"))
        #expect(modelInfo.totalSize == totalSize)

        print("Downloaded GGUF model: \(modelInfo.name)")
        print("   Size: \(modelInfo.totalSize)")
        print("   path: \(modelInfo.location.path)")

        // List the actual files in the model directory recursively
        print("\n📂 Model Directory Contents:")
        listFiles(at: modelInfo.location)

        // Validate files
        try validateGGUFModelStructure(at: modelInfo.location)

        // Clean up: Delete the downloaded model
        try await downloader.deleteModel(model: sendableModel.location)
        print("🧹 Cleaned up: GGUF model deleted after test")
    }

    /// Demonstrates how to download a CoreML format model.
    /// CoreML models may come as .mlmodel, .mlpackage, or .zip files.
    @Test("Download CoreML model with automatic ZIP extraction")
    @MainActor
    func downloadCoreMLModel() async throws {
        let context: TestDownloaderContext = TestDownloaderContext()
        defer { context.cleanup() }
        let downloader: ModelDownloader = context.downloader

        print("\n🔄 Starting CoreML model download test...")
        print("Target model: coreml-community/coreml-stable-diffusion-2-1-base")

        // Create a SendableModel for CoreML format
        let sendableModel: SendableModel = SendableModel(
            id: UUID(),
            ramNeeded: 4_000_000_000, // 4GB
            modelType: .diffusion,
            location: "coreml-community/coreml-stable-diffusion-2-1-base",
            architecture: .stableDiffusion,
            backend: SendableModel.Backend.coreml,
            locationKind: .huggingFace
        )

        let _: Int64 = await registerCoreMLFixture(
            in: context,
            modelId: sendableModel.location,
            name: sendableModel.location
        )

        actor ProgressTracker {
            private var downloadedFiles: [String] = []
            private var totalBytesDownloaded: Int64 = 0

            func addFile(_ fileName: String) {
                if !downloadedFiles.contains(fileName) {
                    downloadedFiles.append(fileName)
                }
            }

            func updateBytes(_ bytes: Int64) {
                totalBytesDownloaded = bytes
            }

            func getFiles() -> [String] {
                downloadedFiles
            }

            func getTotalBytes() -> Int64 {
                totalBytesDownloaded
            }
        }

        let tracker: ProgressTracker = ProgressTracker()
        var modelInfo: ModelInfo?

        // CoreML models support ZIP extraction automatically
        for try await event: DownloadEvent in downloader.downloadModel(sendableModel: sendableModel) {
            switch event {
            case .progress(let progress):
                // Progress includes both download and extraction phases
                if let fileName = progress.currentFileName {
                    Task {
                        await tracker.addFile(fileName)
                    }

                    let mbDownloaded: Double = Double(progress.bytesDownloaded) / 1_000_000
                    let mbTotal: Double = Double(progress.totalBytes) / 1_000_000

                    print(
                        String(
                            format: "[%d/%d] %@ - %.1f/%.1f MB (%d%%)",
                            progress.filesCompleted,
                            progress.totalFiles,
                            fileName,
                            mbDownloaded,
                            mbTotal,
                            Int(progress.percentage)
                        )
                    )
                }
                Task {
                    await tracker.updateBytes(progress.bytesDownloaded)
                }

            case .completed(let info):
                modelInfo = info
                print("Download completed")
            }
        }

        // Verify CoreML format
        guard let modelInfo: ModelInfo else {
            throw PublicAPITestError.downloadDidNotComplete
        }

        #expect(modelInfo.backend == SendableModel.Backend.coreml)

        let downloadedFiles: [String] = await tracker.getFiles()

        print("\nCoreML Model Download Complete!")
        print("Download Summary:")
        print("   Model: \(modelInfo.name)")
        print("   Backend: \(modelInfo.backend)")
        print("   Location: \(modelInfo.location.path)")
        print("   Total Size: \(modelInfo.totalSize / 1_000_000) MB")
        print("   Files Downloaded: \(downloadedFiles.count)")

        print("\nDownloaded Files:")
        for (index, file): (Int, String) in downloadedFiles.enumerated() {
            print("   \(index + 1). \(file)")
        }

        print("\n💾 Storage Details:")
        print("   Model ID: \(modelInfo.id)")
        print("   Download Date: \(modelInfo.downloadDate)")
        print("   Ready for use with Core ML framework")

        // List the actual files in the model directory recursively
        print("\n📂 Model Directory Contents:")
        listFiles(at: modelInfo.location)

        // Validate the files are there
        try validateCoreMLModelStructure(at: modelInfo.location)

        // Clean up: Delete the downloaded model
        try await downloader.deleteModel(model: sendableModel.location)
        print("\n🧹 Cleaned up: CoreML model deleted after test")
    }

    // MARK: - Model Management Examples

    /// Demonstrates how to list all downloaded models.
    @Test("List all downloaded models")
    @MainActor
    func listDownloadedModels() async throws {
        let context: TestDownloaderContext = TestDownloaderContext()
        defer { context.cleanup() }
        let downloader: ModelDownloader = context.downloader

        let modelId: String = "mlx-community/list-model"
        _ = await registerMLXFixture(in: context, modelId: modelId, name: modelId)

        let sendableModel: SendableModel = SendableModel(
            id: UUID(),
            ramNeeded: 512_000_000,
            modelType: .language,
            location: modelId,
            architecture: .llama,
            backend: .mlx,
            locationKind: .huggingFace
        )

        for try await event in downloader.downloadModel(sendableModel: sendableModel) {
            if case .completed = event {
                break
            }
        }

        // Get all models currently downloaded
        let models: [ModelInfo] = try await downloader.listDownloadedModels()

        print("Found \(models.count) downloaded models:")
        for model in models {
            print("   - \(model.name) (\(model.backend)) - \(model.totalSize / 1_000_000) MB")
            print("     ID: \(model.id)")
            print("     Downloaded: \(model.downloadDate)")
        }

        // Models array contains ModelInfo structs with all metadata
        #expect(models.allSatisfy { $0.totalSize > 0 })
    }

    /// Demonstrates how to check if a specific model exists.
    @Test("Check if model exists by ID")
    @MainActor
    func checkModelExists() async throws {
        let context: TestDownloaderContext = TestDownloaderContext()
        defer { context.cleanup() }
        let downloader: ModelDownloader = context.downloader

        let modelId: String = "mlx-community/existence-model"
        _ = await registerMLXFixture(in: context, modelId: modelId, name: modelId)

        let sendableModel: SendableModel = SendableModel(
            id: UUID(),
            ramNeeded: 256_000_000,
            modelType: .language,
            location: modelId,
            architecture: .llama,
            backend: .mlx,
            locationKind: .huggingFace
        )

        for try await event in downloader.downloadModel(sendableModel: sendableModel) {
            if case .completed = event {
                break
            }
        }

        // Check if this model exists
        let exists: Bool = await downloader.modelExists(model: modelId)
        #expect(exists == true)

        print("Model \(modelId) exists: \(exists)")

        // Check for non-existent model
        let notExists: Bool = await downloader.modelExists(model: "non-existent/model")
        #expect(notExists == false)

        print("Random UUID exists: \(notExists)")
    }

    /// Demonstrates how to delete a downloaded model.
    @Test("Delete downloaded model by ID")
    @MainActor
    func deleteModel() async throws {
        let context: TestDownloaderContext = TestDownloaderContext()
        defer { context.cleanup() }
        let downloader: ModelDownloader = context.downloader

        let modelIdToDelete: String = "mlx-community/delete-model"
        _ = await registerMLXFixture(in: context, modelId: modelIdToDelete, name: modelIdToDelete)

        let sendableModel: SendableModel = SendableModel(
            id: UUID(),
            ramNeeded: 128_000_000,
            modelType: .language,
            location: modelIdToDelete,
            architecture: .llama,
            backend: .mlx,
            locationKind: .huggingFace
        )

        for try await event in downloader.downloadModel(sendableModel: sendableModel) {
            if case .completed = event {
                break
            }
        }

        do {
            try await downloader.deleteModel(model: modelIdToDelete)
            print("Successfully deleted model")
        } catch {
            print("Could not delete model: \(error)")
        }

        // Verify deletion
        let stillExists: Bool = await downloader.modelExists(model: modelIdToDelete)
        #expect(stillExists == false)
    }

    /// Demonstrates disk space management utilities.
    @Test("Check available disk space")
    @MainActor
    func checkDiskSpace() async throws {
        let context: TestDownloaderContext = TestDownloaderContext()
        defer { context.cleanup() }
        let downloader: ModelDownloader = context.downloader

        let modelId: String = "mlx-community/space-model"
        _ = await registerMLXFixture(in: context, modelId: modelId, name: modelId)

        let sendableModel: SendableModel = SendableModel(
            id: UUID(),
            ramNeeded: 256_000_000,
            modelType: .language,
            location: modelId,
            architecture: .llama,
            backend: .mlx,
            locationKind: .huggingFace
        )

        for try await event in downloader.downloadModel(sendableModel: sendableModel) {
            if case .completed = event {
                break
            }
        }

        // Check available disk space
        if let availableSpace: Int64 = await downloader.availableDiskSpace() {
            let availableGB: Double = Double(availableSpace) / 1_000_000_000
            print("Available disk space: \(String(format: "%.2f", availableGB)) GB")

            #expect(availableSpace > 0)
        }

        // Get size of a specific model
        if let modelSize: Int64 = await downloader.getModelSize(model: modelId) {
            let sizeMB: Double = Double(modelSize) / 1_000_000
            print("Model \(modelId) size: \(String(format: "%.2f", sizeMB)) MB")
        }
    }

    // MARK: - Advanced Features

    /// Demonstrates download cancellation.
    @Test("Cancel download in progress")
    @MainActor
    func cancelDownload() async throws {
        let context: TestDownloaderContext = TestDownloaderContext()
        defer { context.cleanup() }
        let downloader: ModelDownloader = context.downloader

        let modelId: String = "mlx-community/cancel-model"
        _ = await registerMLXFixture(in: context, modelId: modelId, name: modelId)

        // Start a download task
        Task {
            do {
                let sendableModel: SendableModel = SendableModel(
                    id: UUID(),
                    ramNeeded: 3_758_096_384, // ~3.5GB
                    modelType: .language,
                    location: modelId,
                    architecture: .llama,
                    backend: SendableModel.Backend.mlx,
                    locationKind: .huggingFace
                )

                for try await event: DownloadEvent in downloader.downloadModel(sendableModel: sendableModel) {
                    switch event {
                    case .progress(let progress):
                        print("Downloading... \(Int(progress.percentage))%")

                    case .completed:
                        print("Download completed")
                    }
                }
            } catch {
                print("Download cancelled or failed: \(error)")
            }
        }

        // Wait a moment for download to start
        try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second

        // Cancel the download
        await downloader.cancelDownload(for: modelId)
        print("Cancellation requested")
    }

    /// Demonstrates cleanup of incomplete downloads.
    @Test("Clean up incomplete downloads")
    @MainActor
    func cleanupIncompleteDownloads() async throws {
        let context: TestDownloaderContext = TestDownloaderContext()
        defer { context.cleanup() }
        let downloader: ModelDownloader = context.downloader

        // Clean up any incomplete downloads from failed attempts
        try await downloader.cleanupIncompleteDownloads()

        print("🧹 Cleaned up incomplete downloads")
        print("   This removes partial files from interrupted downloads")
        print("   Helps free up disk space from failed attempts")
    }

    /// Demonstrates using custom directories for models.
    @Test("Use custom model storage directory")
    @MainActor
    func customDirectories() async throws {
        // Create a custom downloader with specific directories
        let baseDir: URL = FileManager.default.temporaryDirectory
            .appendingPathComponent("custom-models-\(UUID().uuidString)")
        let customModelsDir: URL = baseDir.appendingPathComponent("MyModels")
        let customTempDir: URL = baseDir.appendingPathComponent("MyModelsTemp")

        let customDownloader: ModelDownloader = ModelDownloader(
            modelsDirectory: customModelsDir,
            temporaryDirectory: customTempDir
        )

        // Use the custom downloader just like the shared one
        let models: [ModelInfo] = try await customDownloader.listDownloadedModels()

        print("Using custom directories:")
        print("   Models: \(customModelsDir.path)")
        print("   Temp: \(customTempDir.path)")
        print("   Found \(models.count) models in custom location")

        try? FileManager.default.removeItem(at: baseDir)
    }

    // MARK: - SendableModel Workflow Examples

    /// Demonstrates the complete SendableModel → Background Download → File URL workflow
    /// 
    /// This is the primary use case for ModelDownloader:
    /// 1. Create SendableModel with UUID and HuggingFace repository
    /// 2. Download in background with system notifications
    /// 3. Get file URL for model execution (CoreML, LlamaCPP, MLX)
    @Test("Complete SendableModel workflow")
    @MainActor
    func sendableModelWorkflow() async throws {
        print("\nStarting complete SendableModel workflow demonstration")

        let context: TestDownloaderContext = TestDownloaderContext()
        defer { context.cleanup() }
        let downloader: ModelDownloader = context.downloader

        // Step 1: Create SendableModel with known repository
        let modelLocation: String = "mlx-community/Llama-3.2-1B-Instruct-4bit"
        let modelId: UUID = await deterministicModelId(for: modelLocation)
        let model: SendableModel = SendableModel(
            id: modelId,
            ramNeeded: 1_500_000_000,  // 1.5GB RAM requirement
            modelType: .language,
            location: modelLocation,
            architecture: .llama,
            backend: SendableModel.Backend.mlx,
            locationKind: .huggingFace
        )

        _ = await registerMLXFixture(in: context, modelId: model.location, name: model.location)

        print("Created SendableModel:")
        print("   ID: \(model.id)")
        print("   Repository: \(model.location)")
        print("   RAM Needed: \(model.ramNeeded / 1_000_000) MB")
        print("   Type: \(model.modelType)")

        // Step 2: Use recommended format for the model
        let recommendedFormat: SendableModel.Backend = SendableModel.Backend.mlx
        print("\nRecommended format: \(recommendedFormat.rawValue)")

        // Step 3: Validate model before download
        do {
            let validation: ValidationResult = try await downloader.validateModel(
                model.location,
                backend: recommendedFormat
            )
            if !validation.warnings.isEmpty {
                print("\nValidation warnings:")
                for warning: String in validation.warnings {
                    print("   - \(warning)")
                }
            } else {
                print("\nModel validation passed with no warnings")
            }
        } catch {
            print("\nValidation failed: \(error.localizedDescription)")
            throw error
        }

        // Step 4: Download model using SendableModel
        print("\nStarting download...")
        var modelInfo: ModelInfo?

        for try await event in downloader.downloadModel(sendableModel: model) {
            switch event {
            case .progress(let progress):
                if Int(progress.percentage).isMultiple(of: 20) {  // Log every 20%
                    print("   Progress: \(Int(progress.percentage))% - \(progress.currentFileName ?? "Processing...")")
                }

            case .completed(let info):
                modelInfo = info
            }
        }

        guard let modelInfo: ModelInfo else {
            throw PublicAPITestError.downloadDidNotComplete
        }

        print("\nDownload completed!")
        print("   ModelInfo ID: \(modelInfo.id)")
        print("   Backend: \(modelInfo.backend)")
        print("   Size: \(modelInfo.totalSize / 1_000_000) MB")
        print("   Location: \(modelInfo.location.path)")

        // Verify association between SendableModel and ModelInfo
        #expect(modelInfo.id == model.id, "ModelInfo should use SendableModel's UUID")
        #expect(modelInfo.backend == recommendedFormat, "Backend should match recommendation")

        // Step 5: Get model location for execution
        guard let modelLocation: URL = await downloader.getModelLocation(for: model.location) else {
            throw NSError(
                domain: "TestError",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "Could not find model location"]
            )
        }

        print("\n📂 Model location for execution: \(modelLocation.path)")

        // Step 6: List available files in the model directory
        let modelFiles: [URL] = await downloader.getModelFiles(for: model.location)
        print("\nAvailable model files (\(modelFiles.count)):")
        for file: URL in modelFiles {
            print("   - \(file.lastPathComponent)")
        }

        // Step 7: Get specific files for MLX execution
        if recommendedFormat == SendableModel.Backend.mlx {
            let configFile: URL? = await downloader.getModelFileURL(for: model.location, fileName: "config.json")
            let tokenizerFile: URL? = await downloader.getModelFileURL(for: model.location, fileName: "tokenizer.json")
            let weightsFiles: [URL] = modelFiles.filter { $0.pathExtension == "safetensors" }

            print("\nMLX execution files:")
            print("   Config: \(configFile?.lastPathComponent ?? "Not found")")
            print("   Tokenizer: \(tokenizerFile?.lastPathComponent ?? "Not found")")
            print("   Weights: \(weightsFiles.map(\.lastPathComponent).joined(separator: ", "))")

            // These files are essential for MLX
            #expect(configFile != nil, "config.json should be available")
            #expect(!weightsFiles.isEmpty, "At least one .safetensors file should be available")
        }

        // Step 8: Verify model exists
        let modelExists: Bool = await downloader.modelExists(model: model.location)
        #expect(modelExists, "Model should exist after download")

        print("\n🔗 Model existence verified")

        // Cleanup
        try await downloader.deleteModel(model: model.location)
        print("\n🧹 Cleaned up: Model deleted after workflow demonstration")

        print("\nComplete SendableModel workflow demonstration finished successfully!")
    }

    /// Demonstrates background download workflow with SendableModel
    @Test("Background download with SendableModel")
    @MainActor
    func backgroundDownloadWorkflow() async throws {
        print("\n🌙 Starting background download workflow demonstration")

        // Create a SendableModel for background download
        let model: SendableModel = SendableModel(
            id: UUID(),
            ramNeeded: 800_000_000,  // 800MB model
            modelType: .language,
            location: "unsloth/Qwen3-0.6B-GGUF",
            architecture: .qwen,
            backend: SendableModel.Backend.gguf,
            locationKind: .huggingFace
        )

        print("Background download model:")
        print("   ID: \(model.id)")
        print("   Repository: \(model.location)")
        print("   Type: \(model.modelType)")

        let mockExplorer: MockCommunityModelsExplorer = MockCommunityModelsExplorer()
        let discovered: DiscoveredModel = DiscoveredModel(
            id: model.location,
            name: "background-model",
            author: "unsloth",
            downloads: 10,
            likes: 1,
            tags: ["gguf"],
            lastModified: Date(),
            files: [
                ModelFile(path: "model.gguf", size: 128),
                ModelFile(path: "config.json", size: 2)
            ]
        )
        discovered.detectedBackends = [.gguf]
        mockExplorer.discoverModelResponses[model.location] = discovered

        let context: TestDownloaderContext = TestDownloaderContext(communityExplorer: mockExplorer)
        defer { context.cleanup() }
        let downloader: ModelDownloader = context.downloader

        _ = await registerGGUFFixture(in: context, modelId: model.location, name: model.location)

        // Display the backend being used
        print("Using backend: \(model.backend.rawValue)")

        // Configure background download options
        let options: BackgroundDownloadOptions = BackgroundDownloadOptions()
        // options.enableCellular = false  // WiFi only
        // options.isDiscretionary = true  // Let system decide when to download

        // Start background download
        print("\nStarting background download...")
        var handle: BackgroundDownloadHandle?
        var didComplete: Bool = false

        for try await event: BackgroundDownloadEvent in downloader.downloadModelInBackground(
            sendableModel: model.location,
            options: options
        ) {
            switch event {
            case .handle(let downloadHandle):
                handle = downloadHandle
                print("Background download initiated:")
                print("   Download ID: \(downloadHandle.id)")
                print("   Model ID: \(downloadHandle.modelId)")
                print("   Backend: \(downloadHandle.backend)")

            case .progress(let progress):
                print("   Background progress: \(Int(progress.percentage))%")

            case .completed(let info):
                print("Background download completed: \(info.name)")
                didComplete = true
                // For demo, break after completion
            }
        }

        #expect(handle != nil)
        #expect(didComplete)

        // Monitor download status
        let statuses: [BackgroundDownloadStatus] = await downloader.backgroundDownloadStatus()
        print("\nActive background downloads: \(statuses.count)")
        #expect(!statuses.isEmpty)

        for status: BackgroundDownloadStatus in statuses {
            print("   - \(status.handle.modelId): \(status.state.rawValue)")
        }

        // In a real app, you would:
        // 1. Handle background download completion in AppDelegate
        // 2. Show user notification when download completes
        // 3. Update UI to show model is available

        print("\nIn production:")
        print("   1. App receives system notification when download completes")
        print("   2. User gets notification about model availability")
        print("   3. UI updates to show model is ready for use")
        print("   4. Call getModelLocation(for:) to get file URL for inference")

        // Cancel the download for cleanup (in real usage, let it complete)
        if let handle: BackgroundDownloadHandle {
            await downloader.cancelBackgroundDownload(handle)
            print("\n🛑 Background download cancelled for test cleanup")
        }

        print("\nBackground download workflow demonstration completed!")
    }

    /// Demonstrates format recommendation and validation
    @Test("Format recommendation and validation")
    @MainActor
    func formatRecommendationAndValidation() async {
        print("\n🧠 Testing format recommendation and validation")

        let context: TestDownloaderContext = TestDownloaderContext()
        defer { context.cleanup() }
        let downloader: ModelDownloader = context.downloader

        // Test different model types
        let testModels: [SendableModel] = [
            // MLX language model
            SendableModel(
                id: UUID(),
                ramNeeded: 2_000_000_000,
                modelType: .language,
                location: "mlx-community/Llama-3.2-1B-Instruct-4bit",
                architecture: .llama,
                backend: SendableModel.Backend.mlx,
                locationKind: .huggingFace
            ),

            // GGUF model (detected from name)
            SendableModel(
                id: UUID(),
                ramNeeded: 1_000_000_000,
                modelType: .flexibleThinker,
                location: "microsoft/DialoGPT-medium-GGUF",
                architecture: .harmony,
                backend: SendableModel.Backend.gguf,
                locationKind: .huggingFace
            ),

            // Diffusion model
            SendableModel(
                id: UUID(),
                ramNeeded: 4_000_000_000,
                modelType: .diffusion,
                location: "runwayml/stable-diffusion-v1-5",
                architecture: .stableDiffusion,
                backend: SendableModel.Backend.coreml,
                locationKind: .huggingFace
            )
        ]

        for model in testModels {
            print("\n📋 Testing model: \(model.location)")
            print("   Type: \(model.modelType)")

            // Get format recommendation
            let recommendedFormat: SendableModel.Backend = SendableModel.Backend.mlx  // Use MLX as default
            print("   Recommended format: \(recommendedFormat.rawValue)")

            // Test format validation
            do {
                let validation: ValidationResult = try await downloader.validateModel(
                    model.location,
                    backend: recommendedFormat
                )
                print("   Validation: Passed")

                if !validation.warnings.isEmpty {
                    print("   Warnings:")
                    for warning: String in validation.warnings {
                        print("     - \(warning)")
                    }
                }
            } catch {
                print("   Validation: Failed - \(error.localizedDescription)")
            }

            // Test incompatible format
            let incompatibleBackend: SendableModel.Backend = (recommendedFormat == SendableModel.Backend.mlx)
                ? .coreml
                : .mlx
            do {
                _ = try await downloader.validateModel(model.location, backend: incompatibleBackend)
                print("   Incompatible format test: Unexpectedly passed")
            } catch {
                print("   Incompatible format test: Correctly failed - \(error.localizedDescription)")
            }
        }

        print("\nFormat recommendation and validation testing completed!")
    }

    /// Demonstrates error handling scenarios
    @Test("Error handling scenarios")
    @MainActor
    func errorHandlingScenarios() async throws {
        print("\n🚨 Testing error handling scenarios")

        let context: TestDownloaderContext = TestDownloaderContext()
        defer { context.cleanup() }
        let downloader: ModelDownloader = context.downloader

        // Test 1: Invalid repository ID
        let invalidModel: SendableModel = SendableModel(
            id: UUID(),
            ramNeeded: 1_000_000_000,
            modelType: .language,
            location: "invalid-repo-format",  // Missing "/"
            architecture: .unknown,
            backend: SendableModel.Backend.mlx,
            locationKind: .huggingFace
        )

        do {
            _ = try await downloader.validateModel(invalidModel.location, backend: SendableModel.Backend.mlx)
            print("Invalid repository test failed - should have thrown error")
        } catch ModelDownloadError.invalidRepositoryIdentifier {
            print("Invalid repository ID correctly detected")
        } catch {
            print("Unexpected error for invalid repository: \(error)")
        }

        // Test 2: Non-existent repository
        let nonExistentModel: SendableModel = SendableModel(
            id: UUID(),
            ramNeeded: 1_000_000_000,
            modelType: .language,
            location: "does-not-exist/fake-model-12345",
            architecture: .unknown,
            backend: SendableModel.Backend.mlx,
            locationKind: .huggingFace
        )

        _ = downloader.downloadModelSafely(model: nonExistentModel.location)

        // Test 3: Model already downloaded scenario
        // First download a small model
        let testModel: SendableModel = SendableModel(
            id: UUID(),
            ramNeeded: 500_000_000,
            modelType: .language,
            location: "mlx-community/Llama-3.2-1B-Instruct-4bit",
            architecture: .llama,
            backend: SendableModel.Backend.mlx,
            locationKind: .huggingFace
        )

        print("\n🔄 Testing duplicate download detection...")

        _ = await registerMLXFixture(in: context, modelId: testModel.location, name: testModel.location)

        // Download first time
        var modelInfo: ModelInfo?
        for try await event in downloader.downloadModelSafely(model: testModel.location) {
            if case .completed(let info) = event {
                modelInfo = info
            }
        }
        print("First download successful: \(String(describing: modelInfo))")

        // Try to download again
        do {
            for try await _ in downloader.downloadModelSafely(model: testModel.location) {
                // Consume stream
            }
            print("Duplicate download test failed - should have detected existing model")
        } catch ModelDownloadError.modelAlreadyDownloaded {
            print("Duplicate download correctly detected")
        } catch {
            print("Unexpected error for duplicate download: \(error)")
        }

        // Cleanup
        try await downloader.deleteModel(model: testModel.location)
        print("Cleaned up test model")

        print("\nError handling scenarios testing completed!")
    }

    /// Demonstrates file system structure and URL retrieval
    @Test("File system structure and URL retrieval")
    @MainActor
    func fileSystemStructureDemo() async throws {
        print("\n📂 Demonstrating file system structure and URL retrieval")

        let context: TestDownloaderContext = TestDownloaderContext()
        defer { context.cleanup() }
        let downloader: ModelDownloader = context.downloader

        // Download models in different formats to show structure
        let models: [SendableModel] = [
            SendableModel(
                id: UUID(),
                ramNeeded: 1_000_000_000,
                modelType: .language,
                location: "mlx-community/Llama-3.2-1B-Instruct-4bit",
                architecture: .llama,
                backend: SendableModel.Backend.mlx,
                locationKind: .huggingFace
            ),

            SendableModel(
                id: UUID(),
                ramNeeded: 500_000_000,
                modelType: .flexibleThinker,
                location: "unsloth/Qwen3-0.6B-GGUF",
                architecture: .qwen,
                backend: SendableModel.Backend.gguf,
                locationKind: .huggingFace
            )
        ]

        _ = await registerMLXFixture(in: context, modelId: models[0].location, name: models[0].location)
        _ = await registerGGUFFixture(in: context, modelId: models[1].location, name: models[1].location)

        for model in models {
            print("\n📥 Downloading \(model.backend.rawValue.uppercased()) model...")

            var modelInfo: ModelInfo?

            for try await event in downloader.downloadModel(sendableModel: model) {
                switch event {
                case .progress(let progress):
                    if Int(progress.percentage).isMultiple(of: 25) {
                        print("   Progress: \(Int(progress.percentage))%")
                    }

                case .completed(let info):
                    modelInfo = info
                }
            }

            guard let modelInfo: ModelInfo else {
                throw PublicAPITestError.downloadDidNotComplete
            }

            print("Downloaded: \(modelInfo.name)")
            print("📍 Location: \(modelInfo.location.path)")

            // Demonstrate URL retrieval methods
            guard let modelLocation: URL = await downloader.getModelLocation(for: model.location) else {
                throw NSError(
                    domain: "TestError",
                    code: 1,
                    userInfo: [NSLocalizedDescriptionKey: "Model location not found"]
                )
            }

            print("\nFile system structure for \(model.backend.rawValue.uppercased()):")
            print("   Base directory: \(modelLocation.path)")

            let files: [URL] = await downloader.getModelFiles(for: model.location)
            print("   Files (\(files.count)):")
            for file: URL in files {
                let fileSize: Int = (try? file.resourceValues(forKeys: [URLResourceKey.fileSizeKey]))?.fileSize ?? 0
                let sizeMB: Double = Double(fileSize) / 1_000_000
                print("     - \(file.lastPathComponent) (\(String(format: "%.1f", sizeMB)) MB)")
            }

            // Show how to get specific files
            print("\nSpecific file access:")
            switch model.backend {
            case .mlx:
                if let configFile: URL = await downloader.getModelFileURL(
                    for: model.location,
                    fileName: "config.json"
                ) {
                    print("   Config file: \(configFile.path)")
                }
                let safetensorsFiles: [URL] = files.filter { $0.pathExtension == "safetensors" }
                print("   Weights files: \(safetensorsFiles.count) .safetensors files")

            case .gguf:
                let ggufFiles: [URL] = files.filter { $0.pathExtension == "gguf" }
                if let ggufFile: URL = ggufFiles.first {
                    print("   GGUF file: \(ggufFile.lastPathComponent)")
                }

            case .coreml:
                let coremlFiles: [URL] = files.filter { url in
                    url.pathExtension == "mlmodel" || url.pathExtension == "mlpackage"
                }
                print("   CoreML files: \(coremlFiles.count) model files")

            case .remote:
                print("   Remote model: no local files to inspect")
            }

            // Cleanup
            try await downloader.deleteModel(model: model.location)
            print("🧹 Cleaned up \(model.backend.rawValue) model")
        }

        print("\n📋 File System Structure Summary:")
        print("   Models are organized as: ~/Library/Application Support/ThinkAI/Models/{format}/{uuid}/")
        print("   - MLX models: Contains .safetensors, config.json, tokenizer files")
        print("   - GGUF models: Contains .gguf file and config.json")
        print("   - CoreML models: Contains .mlmodel or .mlpackage files")
        print("   Use getModelLocation(for:) to get the base directory")
        print("   Use getModelFileURL(for:fileName:) to get specific files")

        print("\nFile system structure demonstration completed!")
    }
}

// MARK: - Fixture Helpers

@MainActor
private func registerMLXFixture(
    in context: TestDownloaderContext,
    modelId: String,
    name: String
) async -> Int64 {
    let files: [MockHuggingFaceDownloader.FixtureFile] = [
        MockHuggingFaceDownloader.FixtureFile(
            path: "config.json",
            data: Data("{\"config\":true}".utf8),
            size: Int64("{\"config\":true}".utf8.count)
        ),
        MockHuggingFaceDownloader.FixtureFile(
            path: "model.safetensors",
            data: Data(repeating: 0x1, count: 256),
            size: 256
        ),
        MockHuggingFaceDownloader.FixtureFile(
            path: "model.safetensors.index.json",
            data: Data("{\"index\":true}".utf8),
            size: Int64("{\"index\":true}".utf8.count)
        ),
        MockHuggingFaceDownloader.FixtureFile(
            path: "model_info.json",
            data: Data("{\"info\":true}".utf8),
            size: Int64("{\"info\":true}".utf8.count)
        ),
        MockHuggingFaceDownloader.FixtureFile(
            path: "special_tokens_map.json",
            data: Data("{\"special\":true}".utf8),
            size: Int64("{\"special\":true}".utf8.count)
        ),
        MockHuggingFaceDownloader.FixtureFile(
            path: "tokenizer.json",
            data: Data(repeating: 0x2, count: 128),
            size: 128
        ),
        MockHuggingFaceDownloader.FixtureFile(
            path: "tokenizer_config.json",
            data: Data("{\"tokenizer\":true}".utf8),
            size: Int64("{\"tokenizer\":true}".utf8.count)
        )
    ]

    let totalSize: Int64 = files.reduce(0) { $0 + $1.size }

    await context.mockDownloader.registerFixture(
        MockHuggingFaceDownloader.FixtureModel(
            modelId: modelId,
            backend: .mlx,
            name: name,
            files: files
        )
    )

    return totalSize
}

@MainActor
private func registerGGUFFixture(
    in context: TestDownloaderContext,
    modelId: String,
    name: String
) async -> Int64 {
    let files: [MockHuggingFaceDownloader.FixtureFile] = [
        MockHuggingFaceDownloader.FixtureFile(
            path: "model.gguf",
            data: Data(repeating: 0x3, count: 128),
            size: 128
        ),
        MockHuggingFaceDownloader.FixtureFile(
            path: "config.json",
            data: Data("{\"config\":true}".utf8),
            size: Int64("{\"config\":true}".utf8.count)
        ),
        MockHuggingFaceDownloader.FixtureFile(
            path: "model_info.json",
            data: Data("{\"info\":true}".utf8),
            size: Int64("{\"info\":true}".utf8.count)
        )
    ]

    let totalSize: Int64 = files.reduce(0) { $0 + $1.size }

    await context.mockDownloader.registerFixture(
        MockHuggingFaceDownloader.FixtureModel(
            modelId: modelId,
            backend: .gguf,
            name: name,
            files: files
        )
    )

    return totalSize
}

@MainActor
private func registerCoreMLFixture(
    in context: TestDownloaderContext,
    modelId: String,
    name: String
) async -> Int64 {
    let files: [MockHuggingFaceDownloader.FixtureFile] = [
        MockHuggingFaceDownloader.FixtureFile(
            path: "TextEncoder.mlmodelc/model.mil",
            data: Data(repeating: 0x4, count: 64),
            size: 64
        ),
        MockHuggingFaceDownloader.FixtureFile(
            path: "TextEncoder.mlmodelc/metadata.json",
            data: Data("{\"metadata\":true}".utf8),
            size: Int64("{\"metadata\":true}".utf8.count)
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

    let totalSize: Int64 = files.reduce(0) { $0 + $1.size }

    await context.mockDownloader.registerFixture(
        MockHuggingFaceDownloader.FixtureModel(
            modelId: modelId,
            backend: .coreml,
            name: name,
            files: files
        )
    )

    return totalSize
}

@MainActor
private func deterministicModelId(for location: String) async -> UUID {
    let identityService: ModelIdentityService = ModelIdentityService()
    return await identityService.generateModelId(for: location)
}

// MARK: - File Structure Validation Helpers

/// Validates that a CoreML model has the expected directory structure and files
private func validateCoreMLModelStructure(at location: URL) throws {
    let fileManager: FileManager = FileManager.default

    // Ensure at least one .mlmodelc directory exists
    let contents: [URL] = try fileManager.contentsOfDirectory(at: location, includingPropertiesForKeys: nil)
    let mlmodelcDirs: [URL] = contents.filter { $0.pathExtension == "mlmodelc" }
    #expect(!mlmodelcDirs.isEmpty, "Should have at least one .mlmodelc directory")

    for dirURL in mlmodelcDirs {
        let milURL: URL = dirURL.appendingPathComponent("model.mil")
        #expect(fileManager.fileExists(atPath: milURL.path),
               "CoreML file '\(dirURL.lastPathComponent)/model.mil' should exist")
    }

    // Validate root files (allow for disambiguated duplicates like merges_1.txt)
    let expectedRootFiles: [String] = ["merges.txt", "model_info.json", "vocab.json"]
    let rootItems: Set<String> = Set(contents.map(\.lastPathComponent))
    for file: String in expectedRootFiles {
        let expectedURL: URL = URL(fileURLWithPath: file)
        let baseName: String = expectedURL.deletingPathExtension().lastPathComponent
        let ext: String = expectedURL.pathExtension
        let hasExactMatch: Bool = rootItems.contains(file)
        let hasVariantMatch: Bool = rootItems.contains { item in
            item.hasPrefix("\(baseName)_") && item.hasSuffix(".\(ext)")
        }
        #expect(hasExactMatch || hasVariantMatch,
               "CoreML root file '\(file)' should exist")
    }
}

/// Validates that an MLX model has the expected file structure
private func validateMLXModelStructure(at location: URL) throws {
    let fileManager: FileManager = FileManager.default

    let expectedFiles: [String] = [
        "config.json",
        "model.safetensors",
        "model.safetensors.index.json",
        "model_info.json",
        "special_tokens_map.json",
        "tokenizer.json",
        "tokenizer_config.json"
    ]

    for file: String in expectedFiles {
        let fileURL: URL = location.appendingPathComponent(file)
        #expect(fileManager.fileExists(atPath: fileURL.path),
               "MLX file '\(file)' should exist at \(location.path)")
    }

    // Validate minimum file sizes for critical files
    let tokenizerURL: URL = location.appendingPathComponent("tokenizer.json")
    let tokenizerSize: Int = try tokenizerURL.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
    #expect(tokenizerSize > 0,
           "tokenizer.json should be non-empty, found \(tokenizerSize) bytes")

    let modelURL: URL = location.appendingPathComponent("model.safetensors")
    let modelSize: Int = try modelURL.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
    #expect(modelSize > 0,
           "model.safetensors should be non-empty, found \(modelSize) bytes")

    // Validate that safetensors files exist (can be multiple)
    let contents: [URL] = try fileManager.contentsOfDirectory(at: location, includingPropertiesForKeys: nil)
    let safetensorsFiles: [URL] = contents.filter { $0.pathExtension == "safetensors" }
    #expect(!safetensorsFiles.isEmpty,
           "Should have at least one .safetensors file")
}

/// Validates that a GGUF model has the expected file structure
private func validateGGUFModelStructure(at location: URL) throws {
    let fileManager: FileManager = FileManager.default

    // Find .gguf file (should be exactly one)
    let contents: [URL] = try fileManager.contentsOfDirectory(at: location, includingPropertiesForKeys: nil)
    let ggufFiles: [URL] = contents.filter { $0.pathExtension == "gguf" }
    #expect(!ggufFiles.isEmpty,
           "Should have at least one .gguf file, found \(ggufFiles.count)")

    // Validate expected supporting files
    let expectedFiles: [String] = ["config.json", "model_info.json"]
    for file: String in expectedFiles {
        let fileURL: URL = location.appendingPathComponent(file)
        #expect(fileManager.fileExists(atPath: fileURL.path),
               "GGUF file '\(file)' should exist at \(location.path)")
    }

    // Validate GGUF file size
    if let ggufFile: URL = ggufFiles.first {
        let ggufSize: Int = try ggufFile.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
        #expect(ggufSize > 0,
               "GGUF file should be non-empty, found \(ggufSize) bytes")
    }
}
