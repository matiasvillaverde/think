import Foundation
import os

/// Specialized logger for file tree visualization
internal actor FileTreeLogger {
    private let logger: Logger
    private let fileManager: FileManager = FileManager.default

    /// Tree node representation
    private struct TreeNode {
        let name: String
        let path: URL
        let isDirectory: Bool
        let size: Int64?
        let modificationDate: Date?
    }

    internal init() {
        self.logger = Logger(subsystem: "ModelDownloader", category: "fileTree")
    }

    /// Log the entire model repository directory structure
    internal func logModelRepository(baseDirectory: URL) {
        logger.notice("📁 Model Repository Overview")

        do {
            let backends: [String] = ["mlx", "gguf", "coreml"]
            var totalModels: Int = 0
            var totalSize: Int64 = 0

            for backend in backends {
                let backendURL: URL = baseDirectory.appendingPathComponent(backend)
                guard fileManager.fileExists(atPath: backendURL.path) else { continue }

                let models: [URL] = try fileManager.contentsOfDirectory(
                    at: backendURL,
                    includingPropertiesForKeys: [.isDirectoryKey, .fileSizeKey]
                )

                let backendSize: Int64 = calculateDirectorySize(at: backendURL)
                totalSize += backendSize
                totalModels += models.count

                logger.info("Backend \(backend): \(models.count) models, \(self.formatBytes(backendSize))")
            }

            let repoSummary: String = "Repository Summary: \(totalModels) models, " +
                "\(self.formatBytes(totalSize)) total at \(baseDirectory.path)"
            logger.notice("\(repoSummary)")
        } catch {
            logger.error("Failed to analyze model repository: \(error, privacy: .public)")
        }
    }

    /// Log detailed directory tree for a specific path
    internal func logDirectoryTree(
        at url: URL,
        context: String,
        maxDepth: Int = 10,  // Increased default depth to show full tree
        includeHidden: Bool = false
    ) async {
        logger.notice("🌳 Directory Tree: \(context)")

        let startTime: Date = Date()
        let tree: String = await buildTree(at: url, maxDepth: maxDepth, includeHidden: includeHidden)
        let duration: TimeInterval = Date().timeIntervalSince(startTime)

        // Log the tree line by line for better console formatting
        let lines: [Substring] = tree.split(separator: "\n")
        for line in lines {
            logger.debug("\(line)")
        }

        // Log summary statistics
        let stats: DirectoryStats = gatherDirectoryStats(at: url)
        let treeSummary: String = "Tree Summary for \(url.path): \(stats.fileCount) files, " +
            "\(stats.directoryCount) directories, \(formatBytes(stats.totalSize)) total " +
            "(scanned in \(String(format: "%.3fs", duration)))"
        logger.info("\(treeSummary)")
    }

    /// Log CoreML specific model structure
    internal func logCoreMLModelStructure(at modelDirectory: URL) {
        logger.notice("🤖 CoreML Model Structure Analysis")

        do {
            let contents: [URL] = try fileManager.contentsOfDirectory(
                at: modelDirectory,
                includingPropertiesForKeys: [.isDirectoryKey, .fileSizeKey, .contentModificationDateKey]
            )

            // Categorize files
            var mlpackages: [URL] = []
            var mlmodelc: [URL] = []
            var configFiles: [URL] = []
            var otherFiles: [URL] = []

            for item in contents {
                let filename: String = item.lastPathComponent
                if filename.hasSuffix(".mlpackage") {
                    mlpackages.append(item)
                } else if filename.hasSuffix(".mlmodelc") {
                    mlmodelc.append(item)
                } else if filename.hasSuffix(".json") || filename.hasSuffix(".txt") {
                    configFiles.append(item)
                } else {
                    otherFiles.append(item)
                }
            }

            // Log categorized structure
            if !mlpackages.isEmpty {
                let mlpackageNames: String = mlpackages.map(\.lastPathComponent).joined(separator: ", ")
                logger.info("MLPackage Models (\(mlpackages.count)): \(mlpackageNames)")
            }

            if !mlmodelc.isEmpty {
                let compiledNames: String = mlmodelc.map(\.lastPathComponent).joined(separator: ", ")
                logger.info("Compiled Models (\(mlmodelc.count)): \(compiledNames)")

                // Analyze compiled model structure
                for model in mlmodelc {
                    logCompiledModelStructure(at: model)
                }
            }

            if !configFiles.isEmpty {
                let configNames: String = configFiles.map(\.lastPathComponent).joined(separator: ", ")
                logger.info("Configuration Files (\(configFiles.count)): \(configNames)")
            }
        } catch {
            logger.error("Failed to analyze CoreML model structure: \(error)")
        }
    }

    // MARK: - Private Helpers

    private func buildTree(
        at url: URL,
        prefix: String = "",
        depth: Int = 0,
        maxDepth: Int = 3,
        includeHidden: Bool = false,
        isLast: Bool = true
    ) async -> String {
        guard depth < maxDepth else {
            return prefix + "└── ... [max depth reached]"
        }

        var result: String = ""
        let name: String = url.lastPathComponent

        // Get file info
        let isDirectory: Bool = (try? url.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory ?? false
        let fileSize: Int? = (try? url.resourceValues(forKeys: [.fileSizeKey]))?.fileSize

        // Build current line
        if depth > 0 {
            let connector: String = isLast ? "└── " : "├── "
            let sizeInfo: String = isDirectory ? "/" : fileSize.map { " (\(formatBytes(Int64($0))))" } ?? ""
            result += prefix + connector + name + sizeInfo + "\n"
        }

        // Process children if directory
        if isDirectory {
            do {
                let contents: [URL] = try fileManager.contentsOfDirectory(
                    at: url,
                    includingPropertiesForKeys: [.isDirectoryKey, .fileSizeKey],
                    options: includeHidden ? [] : [.skipsHiddenFiles]
                )
                .sorted { $0.lastPathComponent < $1.lastPathComponent }

                for (index, item) in contents.enumerated() {
                    let isLastItem: Bool = index == contents.count - 1
                    let childPrefix: String = depth == 0 ? "" : prefix + (isLast ? "    " : "│   ")

                    result += await buildTree(
                        at: item,
                        prefix: childPrefix,
                        depth: depth + 1,
                        maxDepth: maxDepth,
                        includeHidden: includeHidden,
                        isLast: isLastItem
                    )
                }
            } catch {
                result += prefix + "    [Error reading directory: \(error.localizedDescription)]\n"
            }
        }

        return result
    }

    private func logCompiledModelStructure(at modelURL: URL) {
        let modelName: String = modelURL.lastPathComponent

        do {
            let contents: [URL] = try fileManager.contentsOfDirectory(at: modelURL, includingPropertiesForKeys: nil)
            let totalSize: Int64 = calculateDirectorySize(at: modelURL)

            logger.debug("Compiled Model \(modelName): \(contents.count) files, \(self.formatBytes(totalSize))")
        } catch {
            logger.warning("Could not analyze compiled model: \(modelName)")
        }
    }

    private struct DirectoryStats {
        let fileCount: Int
        let directoryCount: Int
        let totalSize: Int64
    }

    private func gatherDirectoryStats(at url: URL) -> DirectoryStats {
        var fileCount: Int = 0
        var directoryCount: Int = 0
        var totalSize: Int64 = 0

        guard let enumerator: FileManager.DirectoryEnumerator = fileManager.enumerator(
            at: url,
            includingPropertiesForKeys: [.isDirectoryKey, .fileSizeKey]
        ) else {
            return DirectoryStats(fileCount: 0, directoryCount: 0, totalSize: 0)
        }

        while let fileURL = enumerator.nextObject() as? URL {
            let values: URLResourceValues? = try? fileURL.resourceValues(forKeys: [.isDirectoryKey, .fileSizeKey])

            if values?.isDirectory == true {
                directoryCount += 1
            } else {
                fileCount += 1
                if let size: Int = values?.fileSize {
                    totalSize += Int64(size)
                }
            }
        }

        return DirectoryStats(
            fileCount: fileCount,
            directoryCount: directoryCount,
            totalSize: totalSize
        )
    }

    private func calculateDirectorySize(at url: URL) -> Int64 {
        var totalSize: Int64 = 0

        guard let enumerator: FileManager.DirectoryEnumerator = fileManager.enumerator(
            at: url,
            includingPropertiesForKeys: [.fileSizeKey]
        ) else {
            return 0
        }

        while let fileURL = enumerator.nextObject() as? URL {
            if let size: Int = try? fileURL.resourceValues(forKeys: [.fileSizeKey]).fileSize {
                totalSize += Int64(size)
            }
        }

        return totalSize
    }

    private func formatBytes(_ bytes: Int64) -> String {
        let formatter: ByteCountFormatter = ByteCountFormatter()
        formatter.countStyle = .binary
        return formatter.string(fromByteCount: bytes)
    }
}

/// Global file tree logger instance
internal let kFileTreeLogger: FileTreeLogger = FileTreeLogger()
