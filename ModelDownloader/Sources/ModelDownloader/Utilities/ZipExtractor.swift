import Foundation
import ZIPFoundation

/// Utility for extracting ZIP files, particularly for CoreML models
internal struct ZipExtractor: Sendable {
    private let logger: ModelDownloaderLogger

    internal init() {
        self.logger = ModelDownloaderLogger(
            subsystem: "com.think.modeldownloader",
            category: "ZipExtractor"
        )
    }

    /// Extract a ZIP file to a destination directory
    /// - Parameters:
    ///   - zipURL: URL of the ZIP file to extract
    ///   - destinationURL: Directory where files should be extracted
    ///   - progressHandler: Optional progress callback
    /// - Returns: URL of the extracted directory
    internal func extractZip(
        at zipURL: URL,
        to destinationURL: URL,
        progressHandler: ((Double) -> Void)? = nil
    ) async throws -> URL {
        // Get file size for logging
        let zipSize: Int64 = (try? FileManager.default.attributesOfItem(atPath: zipURL.path)[.size] as? Int64) ?? 0
        await logger.info("Starting ZIP extraction", metadata: [
            "source": zipURL.lastPathComponent,
            "size": formatBytes(zipSize),
            "destination": destinationURL.path
        ])

        let startTime: Date = Date()

        do {
            // Ensure destination directory exists
            try FileManager.default.createDirectory(
                at: destinationURL,
                withIntermediateDirectories: true
            )

            let archive: Archive = try Archive(url: zipURL, accessMode: .read)

            // Analyze archive
            let analysis: ArchiveAnalysis = await analyzeArchive(archive, zipSize: zipSize)

            // Extract all entries
            try await extractEntries(
                from: archive,
                to: destinationURL,
                totalEntries: analysis.totalEntries,
                progressHandler: progressHandler
            )

            let duration: TimeInterval = Date().timeIntervalSince(startTime)
            let averageSpeed: Double = duration > 0 ? Double(analysis.totalUncompressedSize) / duration : 0
            await logger.info("ZIP extraction completed successfully", metadata: [
                "duration": String(format: "%.2fs", duration),
                "filesExtracted": analysis.totalEntries,
                "totalSize": formatBytes(analysis.totalUncompressedSize),
                "averageSpeed": formatBytes(Int64(averageSpeed)) + "/s",
                "destination": destinationURL.path
            ])

            return destinationURL
        } catch {
            await logger.error("ZIP extraction failed", error: error, metadata: [
                "source": zipURL.path
            ])
            throw error
        }
    }

    /// Check if a file is a valid ZIP archive
    internal func isValidZip(at url: URL) -> Bool {
        guard FileManager.default.fileExists(atPath: url.path) else {
            return false
        }
        do {
            _ = try Archive(url: url, accessMode: .read)
            return true
        } catch {
            return false
        }
    }

    /// Restructure CoreML model files to have a flat directory structure.
    /// This method finds the directory containing the model files (identified by merges.txt)
    /// and moves all contents to the root level, then removes empty directories.
    ///
    /// - Parameter modelDirectory: The root directory containing the extracted CoreML model
    /// - Throws: File system errors if unable to move files or clean directories
    internal func restructureCoreMLFiles(at modelDirectory: URL) async throws {
        await logger.info("Restructuring CoreML model files to flat structure")

        // Find the directory containing the actual model files
        guard let contentDirectory: URL = findCoreMLContentDirectory(at: modelDirectory) else {
            await logger.info("No nested CoreML content found - structure may already be flat")
            return
        }

        // If content is already at root, nothing to do
        if contentDirectory == modelDirectory {
            await logger.info("CoreML files already at root level")
            return
        }

        await logger.info("Found CoreML content directory", metadata: [
            "path": contentDirectory.path.replacingOccurrences(of: modelDirectory.path + "/", with: "")
        ])

        // Move all contents to root
        try await moveAllContentsToRoot(from: contentDirectory, to: modelDirectory)

        // Clean up empty directories
        try await cleanupEmptyDirectories(in: modelDirectory)

        await logger.info("CoreML restructuring completed successfully")
    }

    /// Find the directory containing CoreML model files by looking for merges.txt.
    /// This is based on the HuggingFace CoreML model structure where merges.txt
    /// is a key indicator of where the model files are located.
    private func findCoreMLContentDirectory(at baseURL: URL) -> URL? {
        let fileManager: FileManager = FileManager.default

        // Check if merges.txt exists at the base level
        let baseMergesPath: URL = baseURL.appendingPathComponent("merges.txt")
        if fileManager.fileExists(atPath: baseMergesPath.path) {
            return baseURL
        }

        // Search subdirectories for merges.txt
        guard let enumerator: FileManager.DirectoryEnumerator = fileManager.enumerator(
            at: baseURL,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else {
            return nil
        }

        while let url: URL = enumerator.nextObject() as? URL {
            if url.lastPathComponent == "merges.txt" {
                // Return the directory containing merges.txt
                return url.deletingLastPathComponent()
            }
        }

        return nil
    }

    /// Move all contents from source directory to destination directory.
    /// Handles naming conflicts by appending numbers to filenames.
    private func moveAllContentsToRoot(from source: URL, to destination: URL) async throws {
        let fileManager: FileManager = FileManager.default

        let contents: [URL] = try fileManager.contentsOfDirectory(
            at: source,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        )

        guard !contents.isEmpty else {
            await logger.warning("No contents to move from source directory")
            return
        }

        await logger.info("Moving \(contents.count) items to root", metadata: [
            "from": source.path.replacingOccurrences(of: destination.path + "/", with: ""),
            "to": "root"
        ])

        for item: URL in contents {
            let filename: String = item.lastPathComponent
            let destURL: URL = resolveDestinationURL(for: filename, in: destination)

            await logger.debug("Moving: \(filename) -> \(destURL.lastPathComponent)")
            try fileManager.moveItem(at: item, to: destURL)
        }
    }

    /// Resolve destination URL, handling naming conflicts by appending numbers.
    private func resolveDestinationURL(for filename: String, in directory: URL) -> URL {
        let fileManager: FileManager = FileManager.default
        var destURL: URL = directory.appendingPathComponent(filename)

        guard fileManager.fileExists(atPath: destURL.path) else {
            return destURL
        }

        // Handle naming conflicts
        let url: URL = URL(fileURLWithPath: filename)
        let name: String = url.deletingPathExtension().lastPathComponent
        let ext: String = url.pathExtension

        var counter: Int = 1
        repeat {
            let newName: String = ext.isEmpty ? "\(name)_\(counter)" : "\(name)_\(counter).\(ext)"
            destURL = directory.appendingPathComponent(newName)
            counter += 1
        } while fileManager.fileExists(atPath: destURL.path)

        return destURL
    }

    /// Recursively remove empty directories.
    private func cleanupEmptyDirectories(in directory: URL) async throws {
        let fileManager: FileManager = FileManager.default

        let contents: [URL] = try fileManager.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        )

        for url: URL in contents {
            guard let resourceValues: URLResourceValues = try? url.resourceValues(forKeys: [.isDirectoryKey]),
                  resourceValues.isDirectory == true else {
                continue
            }

            // Recursively clean subdirectories first
            try await cleanupEmptyDirectories(in: url)

            // Check if this directory is now empty
            let dirContents: [URL] = try fileManager.contentsOfDirectory(
                at: url,
                includingPropertiesForKeys: nil,
                options: []
            )

            if dirContents.isEmpty {
                try fileManager.removeItem(at: url)
                await logger.debug("Removed empty directory: \(url.lastPathComponent)")
            }
        }
    }

    /// Archive analysis result
    private struct ArchiveAnalysis {
        let totalEntries: Int64
        let totalUncompressedSize: Int64
    }

    /// Analyze archive contents
    private func analyzeArchive(_ archive: Archive, zipSize: Int64) async -> ArchiveAnalysis {
        var totalEntries: Int64 = 0
        var totalUncompressedSize: Int64 = 0

        // Count entries and calculate total size
        for entry in archive {
            totalEntries += 1
            if entry.type == .file {
                totalUncompressedSize += Int64(entry.uncompressedSize)
            }
        }

        await logger.info("ZIP archive analysis", metadata: [
            "totalEntries": totalEntries,
            "compressedSize": formatBytes(zipSize),
            "uncompressedSize": formatBytes(totalUncompressedSize),
            "compressionRatio": String(
                format: "%.1f%%",
                zipSize > 0 ? Double(zipSize) / Double(totalUncompressedSize) * 100 : 0
            )
        ])

        return ArchiveAnalysis(
            totalEntries: totalEntries,
            totalUncompressedSize: totalUncompressedSize
        )
    }

    /// Extract entries from archive
    private func extractEntries(
        from archive: Archive,
        to destinationURL: URL,
        totalEntries: Int64,
        progressHandler: ((Double) -> Void)?
    ) async throws {
        var processedEntries: Int64 = 0
        var processedBytes: Int64 = 0
        var lastProgressLog: Int = 0
        var lastDetailedLog: Date = Date()

        for entry in archive {
            let entryURL: URL = destinationURL.appendingPathComponent(entry.path)

            // Log large file extractions
            if entry.type == .file, entry.uncompressedSize > 10_000_000 { // Files > 10MB
                await logger.debug("Extracting large file", metadata: [
                    "file": entry.path,
                    "compressedSize": formatBytes(Int64(entry.compressedSize)),
                    "uncompressedSize": formatBytes(Int64(entry.uncompressedSize))
                ])
            }

            // Ensure the entry's directory exists
            let entryDirectory: URL = entryURL.deletingLastPathComponent()
            try FileManager.default.createDirectory(
                at: entryDirectory,
                withIntermediateDirectories: true
            )

            // Extract the entry
            _ = try archive.extract(entry, to: entryURL)

            processedEntries += 1
            if entry.type == .file {
                processedBytes += Int64(entry.uncompressedSize)
            }

            // Report progress
            if let progressHandler {
                let progress: Double = Double(processedEntries) / Double(totalEntries)
                progressHandler(progress)

                // Log progress at 25% intervals or every 5 seconds
                let progressPercent: Int = Int(progress * 100)
                let timeSinceLastLog: TimeInterval = Date().timeIntervalSince(lastDetailedLog)
                if progressPercent >= lastProgressLog + 25 || timeSinceLastLog >= 5.0 {
                    let currentSpeed: Double = timeSinceLastLog > 0 ?
                        Double(processedBytes) / timeSinceLastLog : 0
                    await logger.info("Extraction progress", metadata: [
                        "progress": "\(progressPercent)%",
                        "filesProcessed": "\(processedEntries)/\(totalEntries)",
                        "bytesProcessed": formatBytes(processedBytes),
                        "currentFile": entry.path.components(separatedBy: "/").last ?? "",
                        "speed": formatBytes(Int64(currentSpeed)) + "/s"
                    ])
                    lastProgressLog = progressPercent - (progressPercent % 25)
                    lastDetailedLog = Date()
                }
            }
        }
    }

    /// Get information about a ZIP file without extracting it
    internal func getZipInfo(at url: URL) async throws -> ZipInfo {
        await logger.debug("Analyzing ZIP file", metadata: ["file": url.lastPathComponent])

        let archive: Archive = try Archive(url: url, accessMode: .read)

        var totalSize: Int64 = 0
        var fileCount: Int = 0
        var directories: Set<String> = []
        var totalEntries: Int = 0

        for entry in archive {
            totalEntries += 1
            if entry.type == .file {
                totalSize += Int64(entry.uncompressedSize)
                fileCount += 1
            } else if entry.type == .directory {
                directories.insert(entry.path)
            }
        }

        await logger.debug("ZIP analysis complete", metadata: [
            "totalEntries": totalEntries,
            "fileCount": fileCount,
            "directoryCount": directories.count,
            "uncompressedSize": totalSize
        ])

        return ZipInfo(
            fileCount: fileCount,
            directoryCount: directories.count,
            totalUncompressedSize: totalSize,
            compressedSize: Int64(totalEntries) // Use total entries as approximation
        )
    }
}

// MARK: - Supporting Types

internal struct ZipInfo: Sendable, Equatable {
    internal let fileCount: Int
    internal let directoryCount: Int
    internal let totalUncompressedSize: Int64
    internal let compressedSize: Int64
}

internal enum ZipExtractionError: Error, LocalizedError, Sendable {
    case extractionFailed(String)
    case insufficientSpace
    case invalidArchive

    internal var errorDescription: String? {
        switch self {
        case .extractionFailed(let reason):
            return "Extraction failed: \(reason)"

        case .insufficientSpace:
            return "Insufficient disk space for extraction"

        case .invalidArchive:
            return "The archive is invalid or corrupted"
        }
    }
}

// MARK: - Private Helpers

private func formatBytes(_ bytes: Int64) -> String {
    let formatter: ByteCountFormatter = ByteCountFormatter()
    formatter.countStyle = .binary
    return formatter.string(fromByteCount: bytes)
}
