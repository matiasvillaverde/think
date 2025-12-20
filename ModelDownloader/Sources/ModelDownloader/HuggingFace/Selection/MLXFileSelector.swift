import Abstractions
import Foundation

/// Selects required MLX files from a repository
internal struct MLXFileSelector {
    private let logger: ModelDownloaderLogger = ModelDownloaderLogger(
        subsystem: "com.think.modeldownloader",
        category: "MLXFileSelector"
    )

    /// Selects required MLX files (weights + tokenizer + config)
    /// - Parameter files: All files available in the model repository
    /// - Returns: Subset of files needed for MLX inference
    internal func selectFiles(from files: [ModelFile]) async -> [ModelFile] {
        guard !files.isEmpty else {
            await logger.warning("No files provided for MLX selection")
            return []
        }

        let selected: [ModelFile] = files.filter { file in
            isRequiredMLXFile(file.path)
        }

        await logger.info("MLX file selection complete", metadata: [
            "totalFiles": files.count,
            "selectedFiles": selected.count
        ])

        return selected
    }

    private func isRequiredMLXFile(_ path: String) -> Bool {
        let filename: String = URL(fileURLWithPath: path).lastPathComponent.lowercased()

        if filename.hasSuffix(".safetensors") {
            return true
        }

        let requiredFilenames: Set<String> = [
            "config.json",
            "generation_config.json",
            "tokenizer.json",
            "tokenizer.model",
            "tokenizer_config.json",
            "special_tokens_map.json",
            "added_tokens.json",
            "vocab.json",
            "vocab.txt",
            "merges.txt",
            "spiece.model",
            "preprocessor_config.json"
        ]

        return requiredFilenames.contains(filename)
    }
}
