import Abstractions
import Foundation

/// Service for detecting supported backends from model file listings
///
/// Analyzes file extensions and patterns to determine which backends
/// (MLX, GGUF, CoreML) a model supports.
internal actor BackendDetector {
    private let logger: ModelDownloaderLogger

    internal init() {
        self.logger = ModelDownloaderLogger(
            subsystem: "com.think.modeldownloader",
            category: "BackendDetector"
        )
    }

    /// Detect supported backends from a list of model files
    /// - Parameter files: Array of model files to analyze
    /// - Returns: Array of detected backends (may be empty)
    internal func detectBackends(from files: [ModelFile]) async -> [SendableModel.Backend] {
        var detectedBackends: Set<SendableModel.Backend> = Set<SendableModel.Backend>()

        // Log file analysis
        await logger.debug("Analyzing \(files.count) files for backend detection")

        // Check for MLX backend indicators
        if hasMLXFiles(in: files) {
            detectedBackends.insert(.mlx)
            await logger.debug("Detected MLX backend support")
        }

        // Check for GGUF backend indicators
        if hasGGUFFiles(in: files) {
            detectedBackends.insert(.gguf)
            await logger.debug("Detected GGUF backend support")
        }

        // Check for CoreML backend indicators
        if hasCoreMLFiles(in: files) {
            detectedBackends.insert(.coreml)
            await logger.debug("Detected CoreML backend support")
        }

        let backends: [SendableModel.Backend] = Array(detectedBackends).sorted { $0.rawValue < $1.rawValue }
        await logger.info("Detected backends", metadata: ["backends": backends.map(\.rawValue)])

        return backends
    }

    /// Detect supported backends from model tags (more efficient than file analysis)
    /// - Parameters:
    ///   - tags: Array of model tags from HuggingFace API
    ///   - files: Optional array of model files for additional verification
    /// - Returns: Array of detected backends
    internal func detectBackends(
        from tags: [String],
        files: [ModelFile] = []
    ) async -> [SendableModel.Backend] {
        var detectedBackends: Set<SendableModel.Backend> = Set<SendableModel.Backend>()

        await logger.debug("Analyzing \(tags.count) tags and \(files.count) files for backend detection")

        // Check for MLX backend indicators in tags
        let mlxTags: [String] = ["mlx", "safetensors"]
        if tags.contains(where: { tag in mlxTags.contains(tag.lowercased()) }) {
            detectedBackends.insert(.mlx)
            await logger.debug("Detected MLX backend from tags")
        }

        // Check for GGUF backend indicators in tags
        if tags.contains(where: { $0.lowercased().contains("gguf") }) {
            detectedBackends.insert(.gguf)
            await logger.debug("Detected GGUF backend from tags")
        }

        // Check for CoreML backend indicators in tags
        if tags.contains(where: { $0.lowercased().contains("coreml") }) {
            detectedBackends.insert(.coreml)
            await logger.debug("Detected CoreML backend from tags")
        }

        // If no backends detected from tags, fall back to file analysis
        if detectedBackends.isEmpty, !files.isEmpty {
            await logger.debug("No backends detected from tags, falling back to file analysis")
            return await detectBackends(from: files)
        }

        let backends: [SendableModel.Backend] = Array(detectedBackends).sorted { $0.rawValue < $1.rawValue }
        await logger.info("Detected backends", metadata: ["backends": backends.map(\.rawValue)])

        return backends
    }

    /// Check if files indicate MLX support
    private func hasMLXFiles(in files: [ModelFile]) -> Bool {
        // Need at least safetensors and config for valid MLX model
        let hasSafetensors: Bool = files.contains { file in
            file.path.lowercased().hasSuffix(".safetensors")
        }
        let hasConfig: Bool = files.contains { file in
            file.path.lowercased().contains("config.json")
        }

        return hasSafetensors && hasConfig
    }

    /// Check if files indicate GGUF support
    private func hasGGUFFiles(in files: [ModelFile]) -> Bool {
        // GGUF models have .gguf files
        files.contains { file in
            file.path.hasSuffix(".gguf") ||
            file.path.hasSuffix(".GGUF")
        }
    }

    /// Check if files indicate CoreML support
    private func hasCoreMLFiles(in files: [ModelFile]) -> Bool {
        let coreMLIndicators: [(ModelFile) -> Bool] = [
            // CoreML model packages
            { (file: ModelFile) in file.path.lowercased().hasSuffix(".mlpackage") },
            // Legacy CoreML models
            { (file: ModelFile) in file.path.lowercased().hasSuffix(".mlmodel") },
            // Compiled CoreML models in zip archives
            { (file: ModelFile) in file.path.lowercased().hasSuffix(".mlmodelc.zip") },
            // CoreML models in specific directory structures
            { (file: ModelFile) in
                file.path.lowercased().hasSuffix(".zip") &&
                CoreMLDetector.isCoreMLPath(file.path)
            }
        ]

        return files.contains { file in
            coreMLIndicators.contains { indicator in
                indicator(file)
            }
        }
    }

    /// Analyze a single file to determine potential backends
    /// - Parameter file: The file to analyze
    /// - Returns: Array of potential backends for this file
    internal func analyzeFile(_ file: ModelFile) -> [SendableModel.Backend] {
        var backends: [SendableModel.Backend] = []

         let filename: String = file.filename.lowercased()
         let path: String = file.path.lowercased()

        // Check for backend-specific patterns
        if filename.hasSuffix(".safetensors") || path.contains("mlx") {
            backends.append(.mlx)
        }

        if filename.hasSuffix(".gguf") {
            backends.append(.gguf)
        }

        if filename.hasSuffix(".mlpackage") ||
           filename.hasSuffix(".mlmodel") ||
           (filename.hasSuffix(".zip") && path.contains("coreml")) {
            backends.append(.coreml)
        }

        return backends
    }
}
