import Abstractions
import Foundation

/// Selects optimal CoreML files based on repository structure and device capabilities
internal actor CoreMLFileSelector {
    private let logger: ModelDownloaderLogger = ModelDownloaderLogger(
        subsystem: "com.think.modeldownloader",
        category: "CoreMLFileSelector"
    )

    /// Initialize CoreML file selector
    internal init() {}

    /// Select the best CoreML files from available options
    /// - Parameter files: All files from repository
    /// - Returns: Selected CoreML files and metadata
    internal func selectFiles(from files: [FileInfo]) async -> [FileInfo] {
        guard !files.isEmpty else {
            return []
        }

        // Log repository analysis
        let totalSize: Int64 = files.reduce(0) { $0 + $1.size }
        await logger.info("Analyzing CoreML repository structure", metadata: [
            "totalFiles": files.count,
            "totalSize": formatBytes(totalSize)
        ])

        // First, check if this is a legacy repository with root-level files
        let rootCoreMLFiles: [FileInfo] = files.filter { file in
            isRootLevelCoreMLFile(file.path)
        }

        // Check if we have subdirectory models
        let subdirModels: [FileInfo] = files.filter { file in
            !isRootLevelCoreMLFile(file.path) && isCoreMLModelFile(file.path)
        }

        // Log file categorization
        await logger.debug("File categorization", metadata: [
            "rootCoreMLFiles": rootCoreMLFiles.count,
            "subdirModels": subdirModels.count,
            "rootFiles": rootCoreMLFiles.prefix(5).map(\.path).joined(separator: ", "),
            "subdirFiles": subdirModels.prefix(5).map(\.path).joined(separator: ", ")
        ])

        // If we have both root and subdirectory models, prefer subdirectory
        if !subdirModels.isEmpty {
            await logger.info("Found CoreML models in subdirectories, using modern selection")
            return await selectModernFiles(from: files)
        }
        if !rootCoreMLFiles.isEmpty {
            await logger.info("Detected legacy CoreML repository with root-level files")
            return await selectLegacyFiles(from: files)
        }

        // No CoreML files found
        await logger.warning("No CoreML files found in repository")
        return []
    }

    // MARK: - Legacy Repository Support

    private func selectLegacyFiles(from files: [FileInfo]) async -> [FileInfo] {
        var selectedFiles: [FileInfo] = []

        // Select .mlmodel over .mlpackage for backward compatibility
        if let mlmodel = files.first(where: { $0.path.hasSuffix(".mlmodel") }) {
            selectedFiles.append(mlmodel)
        } else if let mlpackage = files.first(where: { $0.path.hasSuffix(".mlpackage") }) {
            selectedFiles.append(mlpackage)
        }

        // Include essential metadata files
        selectedFiles.append(contentsOf: selectMetadataFiles(from: files))

        await logger.info("Selected files from legacy repository", metadata: [
            "fileCount": selectedFiles.count,
            "files": selectedFiles.map(\.path).joined(separator: ", "),
            "totalSize": formatBytes(selectedFiles.reduce(0) { $0 + $1.size })
        ])
        return selectedFiles
    }

    // MARK: - Modern Repository Support

    private func selectModernFiles(from files: [FileInfo]) async -> [FileInfo] {
        // Group files by variant (original vs split_einsum)
        let variantGroups: [String: [FileInfo]] = groupFilesByVariant(files)

        // Select optimal variant
        let selectedVariant: String = selectOptimalVariant(from: variantGroups)
        guard let variantFiles = variantGroups[selectedVariant] else {
            await logger.warning("No files found for selected variant: \(selectedVariant)")
            return []
        }

        await logger.info("Selected CoreML variant: \(selectedVariant)", metadata: [
            "reason": selectedVariant == "split_einsum" ? "Better performance on iOS devices" : "Original format",
            "fileCount": variantFiles.count
        ])

        // Within the variant, select appropriate format
        let selectedFiles: [FileInfo] = selectOptimalFormat(from: variantFiles, variant: selectedVariant)

        // Add metadata files
        var result: [FileInfo] = selectedFiles
        result.append(contentsOf: selectMetadataFiles(from: files))

        await logger.info("CoreML file selection complete", metadata: [
            "totalFiles": result.count,
            "modelFiles": selectedFiles.count,
            "metadataFiles": result.count - selectedFiles.count,
            "totalSize": formatBytes(result.reduce(0) { $0 + $1.size }),
            "selectedFiles": result.map(\.path).joined(separator: ", ")
        ])
        return result
    }

    // MARK: - File Grouping

    private func groupFilesByVariant(_ files: [FileInfo]) -> [String: [FileInfo]] {
        var groups: [String: [FileInfo]] = [:]

        for file in files {
            // Handle various path patterns for original variant
            if file.path.contains("original/") {
                if groups["original"] == nil {
                    groups["original"] = []
                }
                groups["original"]?.append(file)
            }
            // Handle both hyphen and underscore versions of split-einsum
            else if let variant = CoreMLDetector.getCoreMLVariant(file.path),
                    variant == .splitEinsum {
                if groups["split_einsum"] == nil {
                    groups["split_einsum"] = []
                }
                groups["split_einsum"]?.append(file)
            }
            // Also check for files that might be CoreML models in subdirectories
            else if isCoreMLModelFile(file.path), file.path.contains("/") {
                // Check if this is a subdirectory model file
                let pathComponents: [Substring] = file.path.split(separator: "/")
                if pathComponents.count > 1 {
                    // Group unrecognized subdirectory models
                    let firstDir: String = String(pathComponents[0])
                    if firstDir == "split-einsum" || firstDir == "split_einsum" {
                        if groups["split_einsum"] == nil {
                            groups["split_einsum"] = []
                        }
                        groups["split_einsum"]?.append(file)
                    }
                }
            }
        }

        return groups
    }

    // MARK: - Selection Logic

    private func selectOptimalVariant(from groups: [String: [FileInfo]]) -> String {
        // Prefer split_einsum for better performance and smaller size
        if groups["split_einsum"] != nil {
            return "split_einsum"
        }

        // Fallback to original if no split_einsum available
        if groups["original"] != nil {
            return "original"
        }

        // Return the first available variant if neither preferred option exists
        return groups.keys.first ?? "original"
    }

    private func selectOptimalFormat(from files: [FileInfo], variant _: String) -> [FileInfo] {
        var selectedFiles: [FileInfo] = []

        // For CoreML, we want to select only ONE ZIP file per variant
        // Priority: Look for ZIP files first as they contain the complete model
        let zipFiles: [FileInfo] = files.filter { $0.path.hasSuffix(".zip") }

        if !zipFiles.isEmpty {
            // If we have ZIP files, select only one
            // Prefer compiled directory if available
            let compiledZips: [FileInfo] = zipFiles.filter { $0.path.contains("/compiled/") }
            if let selectedZip = compiledZips.first {
                selectedFiles = [selectedZip]
                Task { await logger.info("Selected compiled ZIP file: \(selectedZip.path)", metadata: [
                    "size": formatBytes(selectedZip.size),
                    "format": "Compiled CoreML (optimized)"
                ])
                }
            } else {
                // Apply resolution selection for ZIP files
                let optimalZips: [FileInfo] = selectOptimalResolution(from: zipFiles)
                if let selectedZip = optimalZips.first {
                    selectedFiles = [selectedZip]
                    Task { await logger.info("Selected ZIP file: \(selectedZip.path)", metadata: [
                        "size": formatBytes(selectedZip.size),
                        "resolution": extractResolution(from: selectedZip.path) ?? "unknown"
                    ])
                    }
                }
            }
        } else {
            // No ZIP files, fall back to direct model files
            // For Swift usage, prefer compiled format
            let compiledFiles: [FileInfo] = files.filter { $0.path.contains("/compiled/") }
            if !compiledFiles.isEmpty {
                selectedFiles = compiledFiles.filter { isCoreMLModelFile($0.path) }
            } else {
                // Fallback to packages if no compiled version
                let packageFiles: [FileInfo] = files.filter { $0.path.contains("/packages/") }
                if !packageFiles.isEmpty {
                    selectedFiles = packageFiles.filter { isCoreMLModelFile($0.path) }
                } else {
                    // If no specific subdirectory structure, select all CoreML files from this variant
                    selectedFiles = files.filter { isCoreMLModelFile($0.path) }
                }
            }

            // Handle resolution-based selection only for non-ZIP files
            if selectedFiles.count > 1 {
                selectedFiles = selectOptimalResolution(from: selectedFiles)
            }
        }

        return selectedFiles
    }

    private func selectOptimalResolution(from files: [FileInfo]) -> [FileInfo] {
        // Group by resolution if present
        let resolutionGroups: [String: [FileInfo]] = groupByResolution(files)

        if resolutionGroups.isEmpty {
            // No resolution information, return all files
            return files
        }

        // Prefer 768x768 as a good balance
        if let preferred = resolutionGroups["768x768"] {
            return preferred
        }

        // Otherwise, select the middle resolution
        let sortedResolutions: [String] = resolutionGroups.keys.sorted { res1, res2 in
            extractResolutionValue(res1) < extractResolutionValue(res2)
        }

        if !sortedResolutions.isEmpty {
            let middleIndex: Int = sortedResolutions.count / 2
            let selectedResolution: String = sortedResolutions[middleIndex]
            return resolutionGroups[selectedResolution] ?? files
        }

        return files
    }

    private func groupByResolution(_ files: [FileInfo]) -> [String: [FileInfo]] {
        var groups: [String: [FileInfo]] = [:]

        for file in files {
            if let resolution = extractResolution(from: file.path) {
                if groups[resolution] == nil {
                    groups[resolution] = []
                }
                groups[resolution]?.append(file)
            }
        }

        return groups
    }

    // MARK: - Helper Methods

    private func isRootLevelCoreMLFile(_ path: String) -> Bool {
        // Check if file is at root level (no directory separators except for file extension)
        let components: [Substring] = path.split(separator: "/")
        return components.count == 1 && isCoreMLModelFile(path)
    }

    private func isCoreMLModelFile(_ path: String) -> Bool {
        // Check for standard CoreML file extensions
        if path.hasSuffix(".mlmodel") ||
           path.hasSuffix(".mlpackage") ||
           path.hasSuffix(".mlmodelc.zip") {
            return true
        }

        // Check for ZIP files that might contain CoreML models
        if path.hasSuffix(".zip") {
            // Accept any ZIP in CoreML-related directories
            return CoreMLDetector.isCoreMLPath(path)
        }

        return false
    }

    private func selectMetadataFiles(from files: [FileInfo]) -> [FileInfo] {
        // Essential metadata files for CoreML models
        let essentialMetadata: [String] = [
            "config.json",
            "tokenizer.json",
            "tokenizer_config.json",
            "vocab.json",
            "merges.txt",
            "model_index.json",
            "special_tokens_map.json",
            "preprocessor_config.json"
        ]

        // Include only essential metadata files that are at root level
        return files.filter { file in
            // Skip files in subdirectories
            let components: [Substring] = file.path.split(separator: "/")
            if components.count > 1 {
                return false
            }

            // Check if it's an essential metadata file
             let fileName: String = file.path.lowercased()
            return essentialMetadata.contains { fileName == $0.lowercased() }
        }
    }

    private func extractResolution(from path: String) -> String? {
        // Match patterns like "768x768" or "1024x1024"
        let pattern: String = #"(\d{3,4})x(\d{3,4})"#

        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: path, range: NSRange(path.startIndex..., in: path)) else {
            return nil
        }

        return String(path[Range(match.range, in: path)!])
    }

    private func extractResolutionValue(_ resolution: String) -> Int {
        let components: [Substring] = resolution.split(separator: "x")
        guard let width = components.first,
              let value: Int = Int(width) else {
            return 0
        }
        return value
    }

    private func formatBytes(_ bytes: Int64) -> String {
        let formatter: ByteCountFormatter = ByteCountFormatter()
        formatter.countStyle = .binary
        return formatter.string(fromByteCount: bytes)
    }
}
