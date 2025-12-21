import Abstractions
import Foundation

/// Default implementation of ModelFileManagerProtocol
internal actor ModelFileManager: ModelFileManagerProtocol {
    private let fileManager: FileManager
    private let modelPath: ModelPath
    private let temporaryPath: ModelPath
    private let logger: ModelDownloaderLogger
    private let identityService: ModelIdentityService

    internal init(
        modelsDirectory: URL = ModelPath.defaultModelsDirectory,
        temporaryDirectory: URL = ModelPath.defaultTemporaryDirectory,
        fileManager: FileManager = .default,
        identityService: ModelIdentityService? = nil
    ) {
        self.fileManager = fileManager
        self.modelPath = ModelPath(baseDirectory: modelsDirectory)
        self.temporaryPath = ModelPath(baseDirectory: temporaryDirectory)
        self.identityService = identityService ?? ModelIdentityService()
        self.logger = ModelDownloaderLogger(
            subsystem: "com.think.modeldownloader",
            category: "ModelFileManager"
        )
    }

    // MARK: - ModelFileManagerProtocol

    /// Get model directory for a repository ID (e.g., "mlx-community/llama4")
    nonisolated internal func modelDirectory(for repositoryId: String, backend: SendableModel.Backend) -> URL {
        // Convert repository ID to safe directory name by replacing / with _
        let safeDirName: String = repositoryId.safeDirectoryName
        return modelPath.backendDirectory(for: backend)
            .appendingPathComponent(safeDirName, isDirectory: true)
    }

    internal func listDownloadedModels() async throws -> [ModelInfo] {
        let baseDirectory: URL = modelPath.baseDirectory

        await logger.debug("Listing downloaded models", metadata: [
            "baseDirectory": baseDirectory.path
        ])

        // Ensure base directory exists
        try createDirectoryIfNeeded(baseDirectory)

        var models: [ModelInfo] = []

        // Iterate through backend directories
        for backend in SendableModel.Backend.localCases {
            let backendDir: URL = modelPath.backendDirectory(for: backend)

            guard directoryExists(backendDir) else { continue }

            let modelDirs: [URL] = try fileManager.contentsOfDirectory(
                at: backendDir,
                includingPropertiesForKeys: [.isDirectoryKey],
                options: [.skipsHiddenFiles]
            )
            .filter { url in
                do {
                    let resourceValues: URLResourceValues = try url.resourceValues(
                        forKeys: [.isDirectoryKey]
                    )
                    return resourceValues.isDirectory == true
                } catch {
                    // Note: Cannot log from filter closure context
                    return false
                }
            }

            await logger.debug("Found model directories", metadata: [
                "backend": backend.rawValue,
                "count": modelDirs.count
            ])

            for modelDir in modelDirs {
                let dirName: String = modelDir.lastPathComponent

                // Only process repository-based directories (contain underscores or hyphens)
                // Convert back from safe directory name to repository ID
                let repositoryId: String = dirName.replacingOccurrences(of: "_", with: "/")
                if let modelInfo = await loadRepositoryModelInfo(repositoryId: repositoryId, backend: backend) {
                    models.append(modelInfo)
                }
            }
        }

        await logger.info("Listed downloaded models", metadata: [
            "totalModels": models.count
        ])

        return models
    }

    /// Check if a model exists by repository ID
    internal func modelExists(repositoryId: String) async -> Bool {
        await logger.debug("Checking if model exists by repository", metadata: [
            "repositoryId": repositoryId,
            "baseDirectory": modelPath.baseDirectory.path
        ])

        for backend in SendableModel.Backend.localCases {
            let dir: URL = modelDirectory(for: repositoryId, backend: backend)
            let exists: Bool = directoryExists(dir)
            await logger.debug("Checking backend directory", metadata: [
                "repositoryId": repositoryId,
                "backend": backend.rawValue,
                "path": dir.path,
                "exists": exists
            ])
            if exists {
                return true
            }
        }
        return false
    }

    /// Delete model by repository ID
    internal func deleteModel(repositoryId: String) async throws {
        await logger.info("Deleting model by repository", metadata: ["repositoryId": repositoryId])

        var deleted: Bool = false
        for backend in SendableModel.Backend.localCases {
            let dir: URL = modelDirectory(for: repositoryId, backend: backend)
            if directoryExists(dir) {
                // Log pre-deletion state
                await logPreOperationState(
                    directory: dir,
                    operation: "deleting model \(repositoryId)"
                )

                try fileManager.removeItem(at: dir)
                await logger.debug("Deleted model directory", metadata: [
                    "repositoryId": repositoryId,
                    "backend": backend.rawValue,
                    "path": dir.path
                ])
                deleted = true
            }
        }

        if deleted {
            await logger.info("Model deleted successfully", metadata: ["repositoryId": repositoryId])
            // Log repository state after deletion
            await logModelRepositoryState()
        } else {
            await logger.warning("Model not found for deletion", metadata: ["repositoryId": repositoryId])
        }
    }

    internal func moveModel(from sourceURL: URL, to destinationURL: URL) async throws {
        await logger.info("=== MOVING MODEL START ===", metadata: [
            "source": sourceURL.path,
            "destination": destinationURL.path
        ])

        // Log pre-move state of source
        await logPreOperationState(
            directory: sourceURL,
            operation: "moving from \(sourceURL.lastPathComponent)"
        )

        // Check source exists
        let sourceExists: Bool = fileManager.fileExists(atPath: sourceURL.path)
        var sourceIsDir: ObjCBool = false
        let sourceExistsWithDir: Bool = fileManager.fileExists(atPath: sourceURL.path, isDirectory: &sourceIsDir)

        await logger.info("Source verification", metadata: [
            "sourcePath": sourceURL.path,
            "exists": sourceExists,
            "existsWithDir": sourceExistsWithDir,
            "isDirectory": sourceIsDir.boolValue
        ])

        // Ensure destination directory exists
        let destinationDir: URL = destinationURL.deletingLastPathComponent()

        await logger.info("Creating destination directory", metadata: [
            "destinationDir": destinationDir.path
        ])

        try createDirectoryIfNeeded(destinationDir)

        // Check if destination already exists
        let destExists: Bool = fileManager.fileExists(atPath: destinationURL.path)
        await logger.info("Destination check", metadata: [
            "destinationPath": destinationURL.path,
            "alreadyExists": destExists
        ])

        // Move the files
        do {
            try fileManager.moveItem(at: sourceURL, to: destinationURL)
            await logger.info("Move operation successful")
        } catch {
            await logger.error("Move operation failed", error: error, metadata: [
                "sourceURL": sourceURL.path,
                "destinationURL": destinationURL.path
            ])
            throw error
        }

        // Verify move was successful
        let movedExists: Bool = fileManager.fileExists(atPath: destinationURL.path)
        let sourceStillExists: Bool = fileManager.fileExists(atPath: sourceURL.path)

        await logger.info("=== MOVE MODEL COMPLETE ===", metadata: [
            "source": sourceURL.path,
            "destination": destinationURL.path,
            "destinationExists": movedExists,
            "sourceRemoved": !sourceStillExists,
            "success": movedExists && !sourceStillExists
        ])

        // Log post-move state of destination
        if movedExists {
            await logPostOperationState(
                directory: destinationURL,
                operation: "moving to \(destinationURL.lastPathComponent)"
            )
        }
    }

    /// Get model size by repository ID
    internal func getModelSize(repositoryId: String) -> Int64? {
        for backend in SendableModel.Backend.localCases {
            let dir: URL = modelDirectory(for: repositoryId, backend: backend)
            if directoryExists(dir) {
                return calculateDirectorySize(dir)
            }
        }
        return nil
    }

    internal func hasEnoughSpace(for size: Int64) async -> Bool {
        guard let availableSpace = availableDiskSpace() else {
            await logger.warning("Unable to determine available disk space")
            return false
        }
        // Require 20% buffer space
        let bufferMultiplier: Double = 1.2
        let requiredSpace: Int64 = Int64(Double(size) * bufferMultiplier)
        let hasSpace: Bool = availableSpace >= requiredSpace

        await logger.debug("Disk space check", metadata: [
            "requestedSize": size,
            "requiredWithBuffer": requiredSpace,
            "availableSpace": availableSpace,
            "hasEnoughSpace": hasSpace
        ])

        return hasSpace
    }

    /// Get temporary directory for repository ID
    nonisolated internal func temporaryDirectory(for repositoryId: String) -> URL {
        // Convert repository ID to safe directory name by replacing / with _
        let safeDirName: String = repositoryId.safeDirectoryName
        return temporaryPath.baseDirectory.appendingPathComponent(safeDirName, isDirectory: true)
    }

    /// Finalize download for repository-based model
    internal func finalizeDownload(
        repositoryId: String,
        name: String,
        backend: SendableModel.Backend,
        from tempURL: URL,
        totalSize: Int64
    ) async throws -> ModelInfo {
        await logger.info("=== FINALIZING REPOSITORY-BASED DOWNLOAD START ===", metadata: [
            "repositoryId": repositoryId,
            "name": name,
            "backend": backend.rawValue,
            "tempURL": tempURL.path
        ])

        // Log pre-finalization state
        await logPreOperationState(
            directory: tempURL,
            operation: "finalizing download for \(repositoryId)"
        )

        // Check if temp directory exists
        let tempExists: Bool = fileManager.fileExists(atPath: tempURL.path)
        guard tempExists else {
            await logger.error("FINALIZE FAILED: Temporary download directory not found", metadata: [
                "tempPath": tempURL.path
            ])
            throw CocoaError(.fileNoSuchFile, userInfo: [
                NSFilePathErrorKey: tempURL.path,
                NSLocalizedDescriptionKey: "Temporary download directory not found"
            ])
        }

        // Get final destination directory
        let finalURL: URL = modelDirectory(for: repositoryId, backend: backend)

        await logger.info("Moving from temp to final location", metadata: [
            "from": tempURL.path,
            "to": finalURL.path
        ])

        // Ensure parent directory exists
        try createDirectoryIfNeeded(finalURL.deletingLastPathComponent())

        // Remove existing model if it exists
        if directoryExists(finalURL) {
            await logger.info("Removing existing model directory", metadata: [
                "path": finalURL.path
            ])
            try fileManager.removeItem(at: finalURL)
        }

        // Move the files
        try fileManager.moveItem(at: tempURL, to: finalURL)

        await logger.info("Files moved successfully", metadata: [
            "finalLocation": finalURL.path
        ])

        // For CoreML models, flatten the directory structure
        if backend == .coreml {
            await logger.info("CoreML model detected - analyzing structure", metadata: [
                "finalURL": finalURL.path,
                "repositoryId": repositoryId
            ])

            // Log the current directory structure before flattening
            await logDirectoryTree(at: finalURL, context: "CoreML model structure before flattening")

            // Check if we can find key CoreML files
            let mergesPath: URL = finalURL.appendingPathComponent("merges.txt")
            let mergesAtRoot: Bool = fileManager.fileExists(atPath: mergesPath.path)

            await logger.info("CoreML file check", metadata: [
                "merges.txt at root": mergesAtRoot,
                "checking for nested structure": !mergesAtRoot
            ])

            await flattenCoreMLModelStructure(at: finalURL)
        }

        // Log post-finalization state
        await logPostOperationState(
            directory: finalURL,
            operation: "finalizing download for \(repositoryId)"
        )

        // Log the complete model structure
        await logModelStructure(for: repositoryId, backend: backend)

        // Generate a deterministic UUID from repository ID using consistent identity service
        let modelId: UUID = await identityService.generateModelId(for: repositoryId)

        // Create ModelInfo
        let modelInfo: ModelInfo = ModelInfo(
            id: modelId,
            name: name,
            backend: backend,
            location: finalURL,
            totalSize: totalSize,
            downloadDate: Date(),
            metadata: [
                "repositoryId": repositoryId,
                "source": "huggingface",
                "downloadType": "repository-based"
            ]
        )

        await logger.info("=== FINALIZE REPOSITORY-BASED DOWNLOAD COMPLETE ===", metadata: [
            "repositoryId": repositoryId,
            "modelId": modelId.uuidString,
            "totalSize": totalSize,
            "location": finalURL.path,
            "success": true
        ])

        return modelInfo
    }

    internal func cleanupIncompleteDownloads() async throws {
        let tempBaseDir: URL = temporaryPath.baseDirectory

        await logger.info("Starting cleanup of incomplete downloads", metadata: [
            "tempDirectory": tempBaseDir.path
        ])

        guard directoryExists(tempBaseDir) else {
            await logger.debug("No temporary directory to clean")
            return
        }

        // Log pre-cleanup state
        await logPreOperationState(
            directory: tempBaseDir,
            operation: "cleaning up incomplete downloads"
        )

        let contents: [URL] = try fileManager.contentsOfDirectory(
            at: tempBaseDir,
            includingPropertiesForKeys: [.isDirectoryKey, .contentModificationDateKey],
            options: [.skipsHiddenFiles]
        )

        let hoursPerDay: Double = 24
        let minutesPerHour: Double = 60
        let secondsPerMinute: Double = 60
        let hoursInSeconds: Double = hoursPerDay * minutesPerHour * secondsPerMinute
        let cutoffDate: Date = Date().addingTimeInterval(-hoursInSeconds) // 24 hours ago

        var cleanedCount: Int = 0
        for item in contents {
            do {
                let resourceValues: URLResourceValues = try item.resourceValues(
                    forKeys: [.isDirectoryKey, .contentModificationDateKey]
                )

                if resourceValues.isDirectory == true,
                    let modificationDate = resourceValues.contentModificationDate,
                    modificationDate < cutoffDate {
                    try fileManager.removeItem(at: item)
                    cleanedCount += 1
                    await logger.debug("Removed stale temporary directory", metadata: [
                        "path": item.lastPathComponent,
                        "age": Date().timeIntervalSince(modificationDate)
                    ])
                }
            } catch {
                // Continue with cleanup even if individual items fail
                await logger.warning("Failed to clean temporary item", error: error, metadata: [
                    "path": item.path
                ])
                continue
            }
        }

        await logger.info("Cleanup completed", metadata: [
            "itemsCleaned": cleanedCount,
            "totalItems": contents.count
        ])

        // Log post-cleanup state if any items were cleaned
        if cleanedCount > 0 {
            await logPostOperationState(
                directory: tempBaseDir,
                operation: "cleaning up incomplete downloads"
            )
        }
    }

    internal func availableDiskSpace() -> Int64? {
        do {
            let resourceValues: URLResourceValues = try modelPath.baseDirectory.resourceValues(
                forKeys: [.volumeAvailableCapacityForImportantUsageKey]
            )
            return resourceValues.volumeAvailableCapacityForImportantUsage
        } catch {
            return nil
        }
    }

    // MARK: - Private Helpers

    private func directoryExists(_ url: URL) -> Bool {
        var isDirectory: ObjCBool = false
        return fileManager.fileExists(atPath: url.path, isDirectory: &isDirectory)
            && isDirectory.boolValue
    }

    private func createDirectoryIfNeeded(_ url: URL) throws {
        if !(directoryExists(url)) {
            try fileManager.createDirectory(at: url, withIntermediateDirectories: true)
        }
    }

    private func calculateDirectorySize(_ url: URL) -> Int64 {
        do {
            let resourceKeys: [URLResourceKey] = [.isRegularFileKey, .fileSizeKey]
            let enumerator: FileManager.DirectoryEnumerator? = fileManager.enumerator(
                at: url,
                includingPropertiesForKeys: resourceKeys,
                options: [.skipsHiddenFiles]
            )

            var totalSize: Int64 = 0

            while let fileURL = enumerator?.nextObject() as? URL {
                let resourceValues: URLResourceValues = try fileURL.resourceValues(
                    forKeys: Set(resourceKeys)
                )

                if resourceValues.isRegularFile == true {
                    totalSize += Int64(resourceValues.fileSize ?? 0)
                }
            }

            return totalSize
        } catch {
            return 0
        }
    }

    // MARK: - Repository-based Model Info Methods

    /// Load model info for repository-based model
    private func loadRepositoryModelInfo(repositoryId: String, backend: SendableModel.Backend) async -> ModelInfo? {
        let modelDir: URL = modelDirectory(for: repositoryId, backend: backend)

        // Check if model directory exists with files
        guard directoryExists(modelDir) else {
            return nil
        }

        // Get total size of all files in directory
        let totalSize: Int64 = calculateDirectorySize(modelDir)

        // Generate deterministic UUID from repository ID using consistent identity service
        let modelId: UUID = await identityService.generateModelId(for: repositoryId)

        // Create ModelInfo for repository-based model
        return ModelInfo(
            id: modelId,
            name: repositoryId,
            backend: backend,
            location: modelDir,
            totalSize: totalSize,
            downloadDate: Date(), // We don't know the actual date, use current
            metadata: [
                "repositoryId": repositoryId,
                "source": "huggingface",
                "downloadType": "repository-based",
                "synthetic": "true" // Mark as synthetic for debugging
            ]
        )
    }

    // MARK: - CoreML Model Flattening

    /// Flatten CoreML model structure by moving all model files from subdirectories to the root
    private func flattenCoreMLModelStructure(at modelDirectory: URL) async {
        await logger.info("🔧 Flattening CoreML model structure", metadata: [
            "directory": modelDirectory.path
        ])

        // Log initial structure
        await logDirectoryTree(at: modelDirectory, context: "CoreML model before flattening")

        do {
            // Find CoreML model files in any subdirectory
            let coreMLFiles: [URL] = try findCoreMLModelFiles(in: modelDirectory)

            await logger.debug("Found CoreML files", metadata: [
                "directory": modelDirectory.path,
                "count": coreMLFiles.count,
                "files": coreMLFiles.map(\.lastPathComponent)
            ])

            guard !coreMLFiles.isEmpty else {
                await logger.warning("No CoreML model files found to flatten", metadata: [
                    "directory": modelDirectory.path
                ])
                return
            }

            // Group files by their parent directory to log structure
            var filesByDirectory: [URL: [URL]] = [:]
            for file in coreMLFiles {
                let parent: URL = file.deletingLastPathComponent()
                filesByDirectory[parent, default: []].append(file)
            }

            await logger.info("CoreML files distribution", metadata: [
                "totalFiles": coreMLFiles.count,
                "directories": filesByDirectory.count,
                "structure": filesByDirectory.map { dir, files in
                    "\(dir.path): \(files.count) files"
                }
            ])

            // Check if files are already at root level
            let allAtRoot: Bool = coreMLFiles.allSatisfy { file in
                file.deletingLastPathComponent() == modelDirectory
            }

            if allAtRoot {
                await logger.info("CoreML model files already at root level", metadata: [
                    "directory": modelDirectory.path
                ])
                return
            }

            // Move all CoreML files to root
            var movedCount: Int = 0
            var skippedCount: Int = 0

            for sourceFile in coreMLFiles {
                let fileName: String = sourceFile.lastPathComponent
                let destinationFile: URL = modelDirectory.appendingPathComponent(fileName)

                // Skip if source and destination are the same
                if sourceFile == destinationFile {
                    skippedCount += 1
                    continue
                }

                // Handle naming conflicts
                let finalDestination: URL = resolveNamingConflict(for: destinationFile)

                try fileManager.moveItem(at: sourceFile, to: finalDestination)
                movedCount += 1

                await logger.debug("Moved CoreML file", metadata: [
                    "from": sourceFile.path,
                    "to": finalDestination.path,
                    "fileName": fileName
                ])
            }

            await logger.info("Completed CoreML file movement", metadata: [
                "filesMovedCount": movedCount,
                "filesSkippedCount": skippedCount,
                "totalFiles": coreMLFiles.count
            ])

            // Clean up empty directories
            try await cleanupEmptyDirectories(in: modelDirectory)

            // Log final structure
            await logDirectoryTree(at: modelDirectory, context: "CoreML model after flattening")
        } catch {
            await logger.error("Failed to flatten CoreML model structure", error: error, metadata: [
                "directory": modelDirectory.path
            ])
            // Don't throw - this is a non-fatal error
        }
    }

    /// Find all CoreML model files in a directory and its subdirectories
    private func findCoreMLModelFiles(in directory: URL) throws -> [URL] {
        var coreMLFiles: [URL] = []
        var searchDepth: Int = 0

        let enumerator: FileManager.DirectoryEnumerator? = fileManager.enumerator(
            at: directory,
            includingPropertiesForKeys: [.isRegularFileKey, .isDirectoryKey],
            options: [.skipsHiddenFiles]
        )

        while let fileURL = enumerator?.nextObject() as? URL {
            let resourceValues: URLResourceValues = try fileURL.resourceValues(
                forKeys: [.isRegularFileKey, .isDirectoryKey]
            )

            // Calculate depth for logging
            let relativePath: String = fileURL.path.replacingOccurrences(of: directory.path + "/", with: "")
            let currentDepth: Int = relativePath.components(separatedBy: "/").count - 1
            searchDepth = max(searchDepth, currentDepth)

            // Handle .mlmodelc directories (compiled models)
            if resourceValues.isDirectory == true, fileURL.pathExtension == "mlmodelc" {
                coreMLFiles.append(fileURL)
                // Skip enumeration inside .mlmodelc directories
                enumerator?.skipDescendants()
            }
            // Handle .mlpackage directories (CoreML packages)
            else if resourceValues.isDirectory == true, fileURL.pathExtension == "mlpackage" {
                coreMLFiles.append(fileURL)
                // Skip enumeration inside .mlpackage directories
                enumerator?.skipDescendants()
            }
            // Handle regular CoreML files
            else if resourceValues.isRegularFile == true {
                let fileName: String = fileURL.lastPathComponent
                // CoreML-related files to move - expanded list
                if fileName == "merges.txt" || fileName == "vocab.json" ||
                   fileName == "config.json" || fileName == "tokenizer.json" ||
                   fileName == "tokenizer_config.json" || fileName == "special_tokens_map.json" ||
                   fileName == "model_index.json" || fileName == "scheduler_config.json" ||
                   fileURL.pathExtension == "mlmodel" || fileURL.pathExtension == "json" ||
                   fileURL.pathExtension == "txt" || fileName.contains("vocab") ||
                   fileName.contains("merges") || fileName.contains("tokenizer") {
                    coreMLFiles.append(fileURL)
                }
            }
        }

        // Log search results
        Task { @MainActor in
            await logger.debug("CoreML file search completed", metadata: [
                "filesFound": coreMLFiles.count,
                "maxDepth": searchDepth,
                "searchDirectory": directory.path
            ])
        }

        return coreMLFiles
    }

    /// Resolve naming conflicts by appending a number to the filename
    private func resolveNamingConflict(for url: URL) -> URL {
        var finalURL: URL = url
        var counter: Int = 1

        while fileManager.fileExists(atPath: finalURL.path) {
            let nameWithoutExtension: String = url.deletingPathExtension().lastPathComponent
            let pathExtension: String = url.pathExtension

            let newName: String = pathExtension.isEmpty
                ? "\(nameWithoutExtension)_\(counter)"
                : "\(nameWithoutExtension)_\(counter).\(pathExtension)"

            finalURL = url.deletingLastPathComponent().appendingPathComponent(newName)
            counter += 1
        }

        return finalURL
    }

    /// Clean up empty directories after moving files
    private func cleanupEmptyDirectories(in directory: URL) async throws {
        let contents: [URL] = try fileManager.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        )

        for item in contents {
            let resourceValues: URLResourceValues = try item.resourceValues(forKeys: [.isDirectoryKey])

            if resourceValues.isDirectory == true {
                // Skip .mlmodelc directories (they should remain intact)
                if item.pathExtension == "mlmodelc" {
                    continue
                }

                // Recursively clean subdirectories first
                try await cleanupEmptyDirectories(in: item)

                // Check if directory is now empty
                let subContents: [URL] = try fileManager.contentsOfDirectory(
                    at: item,
                    includingPropertiesForKeys: nil,
                    options: [.skipsHiddenFiles]
                )

                if subContents.isEmpty {
                    try fileManager.removeItem(at: item)
                    await logger.debug("Removed empty directory", metadata: [
                        "path": item.lastPathComponent
                    ])
                }
            }
        }
    }

    // MARK: - Directory Tree Visualization

    /// Log the directory tree at a specific URL with context
    internal func logDirectoryTree(at url: URL, context: String) async {
        await kFileTreeLogger.logDirectoryTree(at: url, context: context)
    }

    /// Log the entire model repository state
    internal func logModelRepositoryState() async {
        await kFileTreeLogger.logModelRepository(baseDirectory: modelPath.baseDirectory)
    }

    /// Log the directory tree before a file operation
    internal func logPreOperationState(directory: URL, operation: String) async {
        await logger.info("📸 Pre-operation state", metadata: [
            "operation": operation,
            "directory": directory.path
        ])
        await kFileTreeLogger.logDirectoryTree(
            at: directory,
            context: "Before \(operation)"
        )
    }

    /// Log the directory tree after a file operation
    internal func logPostOperationState(directory: URL, operation: String) async {
        await logger.info("📸 Post-operation state", metadata: [
            "operation": operation,
            "directory": directory.path
        ])
        await kFileTreeLogger.logDirectoryTree(
            at: directory,
            context: "After \(operation)"
        )
    }

    /// Log detailed model structure for debugging
    internal func logModelStructure(for repositoryId: String, backend: SendableModel.Backend) async {
        let modelDir: URL = modelDirectory(for: repositoryId, backend: backend)
        guard directoryExists(modelDir) else {
            await logger.debug("Model directory does not exist", metadata: [
                "repositoryId": repositoryId,
                "backend": backend.rawValue,
                "path": modelDir.path
            ])
            return
        }

        await logger.info("Analyzing model structure", metadata: [
            "repositoryId": repositoryId,
            "backend": backend.rawValue
        ])

        // Log general directory tree
        await kFileTreeLogger.logDirectoryTree(
            at: modelDir,
            context: "Model structure for \(repositoryId)"
        )

        // For CoreML models, perform additional analysis
        if backend == .coreml {
            await kFileTreeLogger.logCoreMLModelStructure(at: modelDir)
        }
    }
}
