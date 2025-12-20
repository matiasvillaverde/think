import Abstractions
import Foundation

/// Centralized service for detecting CoreML models and their characteristics
internal struct CoreMLDetector: Sendable {
    /// Check if a model is CoreML based on model ID and file path
    internal static func isCoreMLModel(
        modelId: String,
        backend: SendableModel.Backend? = nil,
        filePath: String? = nil
    ) -> Bool {
        // Check backend first
        if backend == .coreml {
            return true
        }

        // Check model ID
        let lowercasedModelId: String = modelId.lowercased()
        if lowercasedModelId.contains("coreml") {
            return true
        }

        // Check file path
        if let filePath {
            return isCoreMLPath(filePath)
        }

        return false
    }

    /// Check if a file path indicates CoreML content
    internal static func isCoreMLPath(_ path: String) -> Bool {
        let lowercasedPath: String = path.lowercased()

        return lowercasedPath.contains("coreml") ||
               lowercasedPath.contains("mlmodel") ||
               lowercasedPath.contains("split-einsum") ||
               lowercasedPath.contains("split_einsum") ||
               lowercasedPath.contains("original/") ||
               lowercasedPath.contains("compiled/") ||
               lowercasedPath.contains("packages/")
    }

    /// Check if a file is a CoreML variant (split-einsum or original)
    internal static func isCoreMLVariant(_ path: String) -> Bool {
        let lowercasedPath: String = path.lowercased()

        return lowercasedPath.contains("split-einsum/") ||
               lowercasedPath.contains("split_einsum/") ||
               lowercasedPath.contains("original/")
    }

    /// Get the variant type from a CoreML path
    internal static func getCoreMLVariant(_ path: String) -> CoreMLVariant? {
        let lowercasedPath: String = path.lowercased()

        if lowercasedPath.contains("split-einsum/") || lowercasedPath.contains("split_einsum/") {
            return .splitEinsum
        }
        if lowercasedPath.contains("original/") {
            return .original
        }
        if lowercasedPath.contains("compiled/") {
            return .compiled
        }
        if lowercasedPath.contains("packages/") {
            return .packages
        }

        return nil
    }
}

/// CoreML model variants
internal enum CoreMLVariant: String, Sendable {
    case splitEinsum = "split_einsum"
    case original = "original"
    case compiled = "compiled"
    case packages = "packages"
}
