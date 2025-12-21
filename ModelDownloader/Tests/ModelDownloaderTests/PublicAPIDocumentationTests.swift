import Abstractions
import Foundation
import ModelDownloader
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
    @Test("Download MLX model using public API", .disabled())
    func downloadMLXModel() async throws {
        // Use the shared instance for default configuration
        let downloader: ModelDownloader = ModelDownloader.shared

        // Create a SendableModel for downloading
        let sendableModel: SendableModel = SendableModel(
            id: UUID(),
            ramNeeded: 1_073_741_824, // 1GB
            modelType: .language,
            location: "mlx-community/Llama-3.2-1B-Instruct-4bit",
            architecture: .llama,
            backend: SendableModel.Backend.mlx
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
        #expect(modelInfo.totalSize == 712_575_975)

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
    @Test(
        "Download GGUF model with automatic memory-based selection",
        .disabled("This test are to be run only before releasing the app")
    )
    func downloadGGUFModel() async throws {
        let downloader: ModelDownloader = ModelDownloader.shared

        // Create a SendableModel for GGUF format
        let sendableModel: SendableModel = SendableModel(
            id: UUID(),
            ramNeeded: 600_000_000, // 600MB
            modelType: .language,
            location: "unsloth/Qwen3-0.6B-GGUF",
            architecture: .qwen,
            backend: SendableModel.Backend.gguf
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
        #expect(modelInfo.totalSize == 495_108_528)

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
    @Test(
        "Download CoreML model with automatic ZIP extraction",
        .disabled("This test are to be run only before releasing the app")
    )
    func downloadCoreMLModel() async throws {
        let downloader: ModelDownloader = ModelDownloader.shared

        print("\n🔄 Starting CoreML model download test...")
        print("Target model: coreml-community/coreml-stable-diffusion-2-1-base")

        // Create a SendableModel for CoreML format
        let sendableModel: SendableModel = SendableModel(
            id: UUID(),
            ramNeeded: 4_000_000_000, // 4GB
            modelType: .diffusion,
            location: "coreml-community/coreml-stable-diffusion-2-1-base",
            architecture: .stableDiffusion,
            backend: SendableModel.Backend.coreml
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
    func listDownloadedModels() async throws {
        let downloader: ModelDownloader = ModelDownloader.shared

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
    func checkModelExists() async throws {
        let downloader: ModelDownloader = ModelDownloader.shared

        // First, list models to get a valid ID
        let models: [ModelInfo] = try await downloader.listDownloadedModels()

        if let firstModel: ModelInfo = models.first {
            // Check if this model exists
            let exists: Bool = await downloader.modelExists(model: firstModel.name)
            #expect(exists == true)

            print("Model \(firstModel.name) exists: \(exists)")
        }

        // Check for non-existent model
        let notExists: Bool = await downloader.modelExists(model: "non-existent/model")
        #expect(notExists == false)

        print("Random UUID exists: \(notExists)")
    }

    /// Demonstrates how to delete a downloaded model.
    @Test("Delete downloaded model by ID")
    func deleteModel() async {
        let downloader: ModelDownloader = ModelDownloader.shared

        // Note: In a real app, you'd have a model ID from previous downloads
        // For this example, we'll show the pattern
        let modelIdToDelete: String = "test/model" // Replace with actual model ID

        do {
            try await downloader.deleteModel(model: modelIdToDelete)
            print("Successfully deleted model")
        } catch {
            // Handle case where model doesn't exist
            print("Could not delete model: \(error)")
        }

        // Verify deletion
        let stillExists: Bool = await downloader.modelExists(model: modelIdToDelete)
        #expect(stillExists == false)
    }

    /// Demonstrates disk space management utilities.
    @Test("Check available disk space")
    func checkDiskSpace() async throws {
        let downloader: ModelDownloader = ModelDownloader.shared

        // Check available disk space
        if let availableSpace: Int64 = await downloader.availableDiskSpace() {
            let availableGB: Double = Double(availableSpace) / 1_000_000_000
            print("Available disk space: \(String(format: "%.2f", availableGB)) GB")

            #expect(availableSpace > 0)
        }

        // Get size of a specific model
        let models: [ModelInfo] = try await downloader.listDownloadedModels()
        if let model: ModelInfo = models.first {
            if let modelSize: Int64 = await downloader.getModelSize(model: "test/model") {
                let sizeMB: Double = Double(modelSize) / 1_000_000
                print("Model \(model.name) size: \(String(format: "%.2f", sizeMB)) MB")
            }
        }
    }

    // MARK: - Advanced Features

    /// Demonstrates download cancellation.
    @Test("Cancel download in progress")
    func cancelDownload() async throws {
        let downloader: ModelDownloader = ModelDownloader.shared

        // Start a download task
        Task {
            do {
                let sendableModel: SendableModel = SendableModel(
                    id: UUID(),
                    ramNeeded: 3_758_096_384, // ~3.5GB
                    modelType: .language,
                    location: "mlx-community/Llama-3.2-3B-Instruct-4bit",
                    architecture: .llama,
                    backend: SendableModel.Backend.mlx
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
        await downloader.cancelDownload(for: "mlx-community/Llama-3.2-3B-Instruct-4bit")
        print("Cancellation requested")
    }

    /// Demonstrates cleanup of incomplete downloads.
    @Test("Clean up incomplete downloads")
    func cleanupIncompleteDownloads() async throws {
        let downloader: ModelDownloader = ModelDownloader.shared

        // Clean up any incomplete downloads from failed attempts
        try await downloader.cleanupIncompleteDownloads()

        print("🧹 Cleaned up incomplete downloads")
        print("   This removes partial files from interrupted downloads")
        print("   Helps free up disk space from failed attempts")
    }

    /// Demonstrates using custom directories for models.
    @Test("Use custom model storage directory")
    func customDirectories() async throws {
        // Create a custom downloader with specific directories
        let documentsURL: URL = FileManager.default.urls(
            for: .documentDirectory,
            in: .userDomainMask
        ).first!
        let customModelsDir: URL = documentsURL.appendingPathComponent("MyModels")
        let customTempDir: URL = documentsURL.appendingPathComponent("MyModelsTemp")

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
    }

    // MARK: - SendableModel Workflow Examples

    /// Demonstrates the complete SendableModel → Background Download → File URL workflow
    /// 
    /// This is the primary use case for ModelDownloader:
    /// 1. Create SendableModel with UUID and HuggingFace repository
    /// 2. Download in background with system notifications
    /// 3. Get file URL for model execution (CoreML, LlamaCPP, MLX)
    @Test("Complete SendableModel workflow", .disabled())
    func sendableModelWorkflow() async throws {
        print("\nStarting complete SendableModel workflow demonstration")

        // Step 1: Create SendableModel with known repository
        let model: SendableModel = SendableModel(
            id: UUID(),
            ramNeeded: 1_500_000_000,  // 1.5GB RAM requirement
            modelType: .language,
            location: "mlx-community/Llama-3.2-1B-Instruct-4bit",
            architecture: .llama,
            backend: SendableModel.Backend.mlx
        )

        print("Created SendableModel:")
        print("   ID: \(model.id)")
        print("   Repository: \(model.location)")
        print("   RAM Needed: \(model.ramNeeded / 1_000_000) MB")
        print("   Type: \(model.modelType)")

        let downloader: ModelDownloader = ModelDownloader.shared

        // Step 2: Use recommended format for the model
        let recommendedFormat: SendableModel.Backend = SendableModel.Backend.mlx
        print("\nRecommended format: \(recommendedFormat.rawValue)")

        // Step 3: Validate model before download
        do {
            let validation: ValidationResult = try await downloader.validateModel(
                "test/model",
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
        let modelFiles: [URL] = await downloader.getModelFiles(for: "test/model")
        print("\nAvailable model files (\(modelFiles.count)):")
        for file: URL in modelFiles {
            print("   - \(file.lastPathComponent)")
        }

        // Step 7: Get specific files for MLX execution
        if recommendedFormat == SendableModel.Backend.mlx {
            let configFile: URL? = await downloader.getModelFileURL(for: "test/model", fileName: "config.json")
            let tokenizerFile: URL? = await downloader.getModelFileURL(for: "test/model", fileName: "tokenizer.json")
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
        let modelExists: Bool = await downloader.modelExists(model: "test/model")
        #expect(modelExists, "Model should exist after download")

        print("\n🔗 Model existence verified")

        // Cleanup
        try await downloader.deleteModel(model: model.location)
        print("\n🧹 Cleaned up: Model deleted after workflow demonstration")

        print("\nComplete SendableModel workflow demonstration finished successfully!")
    }

    /// Demonstrates background download workflow with SendableModel
    @Test(
        "Background download with SendableModel",
        .disabled("Background downloads require app bundle and notification permissions")
    )
    func backgroundDownloadWorkflow() async throws {
        print("\n🌙 Starting background download workflow demonstration")

        // Create a SendableModel for background download
        let model: SendableModel = SendableModel(
            id: UUID(),
            ramNeeded: 800_000_000,  // 800MB model
            modelType: .language,
            location: "unsloth/Qwen3-0.6B-GGUF",
            architecture: .qwen,
            backend: SendableModel.Backend.gguf
        )

        print("Background download model:")
        print("   ID: \(model.id)")
        print("   Repository: \(model.location)")
        print("   Type: \(model.modelType)")

        let downloader: ModelDownloader = ModelDownloader.shared

        // Request notification permission first
        let notificationGranted: Bool = await downloader.requestNotificationPermission()
        print("\nNotification permission: \(notificationGranted ? "Granted" : "Denied")")

        // Display the backend being used
        print("Using backend: \(model.backend.rawValue)")

        // Configure background download options
        let options: BackgroundDownloadOptions = BackgroundDownloadOptions()
        // options.enableCellular = false  // WiFi only
        // options.isDiscretionary = true  // Let system decide when to download

        // Start background download
        print("\nStarting background download...")
        var handle: BackgroundDownloadHandle?

        for try await event: BackgroundDownloadEvent in downloader.downloadModelInBackground(
            sendableModel: "test/model",
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
                // For demo, break after completion
            }
        }

        // Monitor download status
        let statuses: [BackgroundDownloadStatus] = await downloader.backgroundDownloadStatus()
        print("\nActive background downloads: \(statuses.count)")

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
    func formatRecommendationAndValidation() async {
        print("\n🧠 Testing format recommendation and validation")

        let downloader: ModelDownloader = ModelDownloader.shared

        // Test different model types
        let testModels: [SendableModel] = [
            // MLX language model
            SendableModel(
                id: UUID(),
                ramNeeded: 2_000_000_000,
                modelType: .language,
                location: "mlx-community/Llama-3.2-1B-Instruct-4bit",
                architecture: .llama,
                backend: SendableModel.Backend.mlx
            ),

            // GGUF model (detected from name)
            SendableModel(
                id: UUID(),
                ramNeeded: 1_000_000_000,
                modelType: .flexibleThinker,
                location: "microsoft/DialoGPT-medium-GGUF",
                architecture: .harmony,
                backend: SendableModel.Backend.gguf
            ),

            // Diffusion model
            SendableModel(
                id: UUID(),
                ramNeeded: 4_000_000_000,
                modelType: .diffusion,
                location: "runwayml/stable-diffusion-v1-5",
                architecture: .stableDiffusion,
                backend: SendableModel.Backend.coreml
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
                    "test/model",
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
                _ = try await downloader.validateModel("test/model", backend: incompatibleBackend)
                print("   Incompatible format test: Unexpectedly passed")
            } catch {
                print("   Incompatible format test: Correctly failed - \(error.localizedDescription)")
            }
        }

        print("\nFormat recommendation and validation testing completed!")
    }

    /// Demonstrates error handling scenarios
    @Test("Error handling scenarios", .disabled())
    func errorHandlingScenarios() async throws {
        print("\n🚨 Testing error handling scenarios")

        let downloader: ModelDownloader = ModelDownloader.shared

        // Test 1: Invalid repository ID
        let invalidModel: SendableModel = SendableModel(
            id: UUID(),
            ramNeeded: 1_000_000_000,
            modelType: .language,
            location: "invalid-repo-format",  // Missing "/"
            architecture: .unknown,
            backend: SendableModel.Backend.mlx
        )

        do {
            _ = try await downloader.validateModel("invalid/model", backend: SendableModel.Backend.mlx)
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
            backend: SendableModel.Backend.mlx
        )

        _ = downloader.downloadModelSafely(model: "non-existent/model")

        // Test 3: Model already downloaded scenario
        // First download a small model
        let testModel: SendableModel = SendableModel(
            id: UUID(),
            ramNeeded: 500_000_000,
            modelType: .language,
            location: "mlx-community/Llama-3.2-1B-Instruct-4bit",
            architecture: .llama,
            backend: SendableModel.Backend.mlx
        )

        print("\n🔄 Testing duplicate download detection...")

        // Download first time
        var modelInfo: ModelInfo?
        for try await event in downloader.downloadModelSafely(model: "test/model") {
            if case .completed(let info) = event {
                modelInfo = info
            }
        }
        print("First download successful: \(String(describing: modelInfo))")

        // Try to download again
        do {
            for try await _ in downloader.downloadModelSafely(model: "test/model") {
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
    @Test("File system structure and URL retrieval", .disabled())
    func fileSystemStructureDemo() async throws {
        print("\n📂 Demonstrating file system structure and URL retrieval")

        let downloader: ModelDownloader = ModelDownloader.shared

        // Download models in different formats to show structure
        let models: [SendableModel] = [
            SendableModel(
                id: UUID(),
                ramNeeded: 1_000_000_000,
                modelType: .language,
                location: "mlx-community/Llama-3.2-1B-Instruct-4bit",
                architecture: .llama,
                backend: SendableModel.Backend.mlx
            ),

            SendableModel(
                id: UUID(),
                ramNeeded: 500_000_000,
                modelType: .flexibleThinker,
                location: "unsloth/Qwen3-0.6B-GGUF",
                architecture: .qwen,
                backend: SendableModel.Backend.gguf
            )
        ]

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

// MARK: - File Structure Validation Helpers

/// Validates that a CoreML model has the expected directory structure and files
private func validateCoreMLModelStructure(at location: URL) throws {
    let fileManager: FileManager = FileManager.default

    // Expected .mlmodelc directories for Stable Diffusion models
    let expectedDirs: [String] = [
        "TextEncoder.mlmodelc",
        "Unet.mlmodelc",
        "UnetChunk1.mlmodelc",
        "UnetChunk2.mlmodelc",
        "VAEDecoder.mlmodelc"
    ]

    for dir: String in expectedDirs {
        let dirURL: URL = location.appendingPathComponent(dir)
        #expect(fileManager.fileExists(atPath: dirURL.path),
               "CoreML directory '\(dir)' should exist at \(location.path)")

        // Validate .mlmodelc internal structure
        let expectedFiles: [String] = ["coremldata.bin", "metadata.json", "model.mil"]
        for file: String in expectedFiles {
            let fileURL: URL = dirURL.appendingPathComponent(file)
            #expect(fileManager.fileExists(atPath: fileURL.path),
                   "CoreML file '\(dir)/\(file)' should exist")
        }

        // Validate analytics directory
        let analyticsURL: URL = dirURL.appendingPathComponent("analytics/coremldata.bin")
        #expect(fileManager.fileExists(atPath: analyticsURL.path),
               "Analytics file should exist in '\(dir)'")

        // Validate weights directory
        let weightsURL: URL = dirURL.appendingPathComponent("weights/weight.bin")
        #expect(fileManager.fileExists(atPath: weightsURL.path),
               "Weights file should exist in '\(dir)'")
    }

    // Validate root files
    let expectedRootFiles: [String] = ["merges.txt", "model_info.json", "vocab.json"]
    for file: String in expectedRootFiles {
        let fileURL: URL = location.appendingPathComponent(file)
        #expect(fileManager.fileExists(atPath: fileURL.path),
               "CoreML root file '\(file)' should exist")
    }

    // Validate that we have exactly 5 .mlmodelc directories
    let contents: [URL] = try fileManager.contentsOfDirectory(at: location, includingPropertiesForKeys: nil)
    let mlmodelcDirs: [URL] = contents.filter { $0.pathExtension == "mlmodelc" }
    #expect(mlmodelcDirs.count == 5,
           "Should have exactly 5 .mlmodelc directories, found \(mlmodelcDirs.count)")
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
    #expect(tokenizerSize > 15_000_000,
           "tokenizer.json should be at least 15MB, found \(tokenizerSize / 1_000_000)MB")

    let modelURL: URL = location.appendingPathComponent("model.safetensors")
    let modelSize: Int = try modelURL.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
    #expect(modelSize > 600_000_000,
           "model.safetensors should be at least 600MB, found \(modelSize / 1_000_000)MB")

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
    #expect(ggufFiles.count == 1,
           "Should have exactly one .gguf file, found \(ggufFiles.count)")

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
        #expect(ggufSize > 400_000_000,
               "GGUF file should be at least 400MB, found \(ggufSize / 1_000_000)MB")
    }
}
