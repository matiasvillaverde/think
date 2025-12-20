import Abstractions
import Foundation

/// Utility for associating SendableModel with ModelInfo and handling conversions
public struct ModelAssociation: Sendable {
    /// Get recommended backend based on model type and backend preference
    /// 
    /// This method provides intelligent backend selection based on the model type:
    /// - Language models typically use MLX or GGUF
    /// - Diffusion models typically use CoreML for optimal performance
    /// - Visual language models can use MLX
    /// 
    /// - Parameters:
    ///   - sendableModel: The SendableModel to analyze
    ///   - preferredBackend: Optional backend preference (mlx, gguf)
    /// - Returns: Recommended Backend for download
    public static func recommendedBackend(
        for sendableModel: SendableModel,
        preferredBackend: SendableModel.Backend? = nil
    ) -> SendableModel.Backend {
        switch sendableModel.modelType {
        case .language, .deepLanguage, .flexibleThinker:
            // Language models: prefer MLX on Apple Silicon, GGUF for compatibility
            if let backend = preferredBackend {
                return backend
            }
            // Default to MLX for Apple Silicon optimization
            return .mlx

        case .diffusion, .diffusionXL:
            // Diffusion models: prefer CoreML for iOS/macOS optimization
            return .coreml

        case .visualLanguage:
            // Visual language models: typically work best with MLX
            return .mlx
        }
    }

    /// Extract backend preference from SendableModel location if it contains format hints
    /// 
    /// Some HuggingFace repositories include format hints in their names:
    /// - "mlx-community/..." → .mlx
    /// - "...GGUF" → .gguf
    /// - "...gguf..." → .gguf
    /// 
    /// - Parameter sendableModel: SendableModel to analyze
    /// - Returns: Detected backend or nil if no hints found
    public static func detectBackendFromLocation(_ sendableModel: SendableModel) -> SendableModel.Backend? {
        let location: String = sendableModel.location.lowercased()

        if location.contains("mlx") || location.hasPrefix("mlx-") {
            return .mlx
        }

        if location.contains("gguf") {
            return .gguf
        }

        return nil
    }

    /// Validate that a SendableModel is compatible with a given backend
    /// 
    /// Performs sanity checks to ensure the model and backend combination makes sense:
    /// - Diffusion models should use CoreML for best performance
    /// - Very large models (>16GB RAM) should prefer GGUF for memory efficiency
    /// - Models with MLX in the repository name should use MLX backend
    /// 
    /// - Parameters:
    ///   - sendableModel: Model to validate
    ///   - backend: Backend to check compatibility with
    /// - Returns: Validation result with warnings/errors
    public static func validateCompatibility(
        sendableModel: SendableModel,
        backend: SendableModel.Backend
    ) -> ValidationResult {
        var warnings: [String] = []
        var isValid: Bool = true

        // Check backend compatibility with model type
        switch (sendableModel.modelType, backend) {
        case (.diffusion, .mlx), (.diffusionXL, .mlx):
            warnings.append("Diffusion models typically perform better with CoreML backend on iOS/macOS")

        case (.diffusion, .gguf), (.diffusionXL, .gguf):
            warnings.append("GGUF backend is not typically used for diffusion models - consider CoreML")
            isValid = false

        case (.language, .coreml), (.deepLanguage, .coreml), (.flexibleThinker, .coreml):
            warnings.append("CoreML backend for language models may have limited support - consider MLX or GGUF")

        default:
            break
        }

        // Check memory requirements
        let ramGB: Double = Double(sendableModel.ramNeeded) / 1_000_000_000
        if ramGB > 16, backend == .mlx {
            warnings.append("Large models (>16GB) may benefit from GGUF format for better memory management")
        }

        // Check repository naming consistency
        if let detectedBackend = detectBackendFromLocation(sendableModel) {
            if detectedBackend != backend {
                warnings.append(
                    "Repository name suggests \(detectedBackend.rawValue) backend, but \(backend.rawValue) was selected"
                )
            }
        }

        return ValidationResult(isValid: isValid, warnings: warnings)
    }

    /// Create metadata dictionary for associating SendableModel with ModelInfo
    /// 
    /// - Parameter sendableModel: SendableModel to extract metadata from
    /// - Returns: Dictionary containing SendableModel metadata
    public static func createMetadata(from sendableModel: SendableModel) -> [String: String] {
        var metadata: [String: String] = [:]

        metadata["sendableModelId"] = sendableModel.id.uuidString
        metadata["modelType"] = sendableModel.modelType.rawValue
        metadata["ramNeeded"] = String(sendableModel.ramNeeded)
        metadata["repositoryId"] = sendableModel.location
        metadata["associatedAt"] = ISO8601DateFormatter().string(from: Date())

        if let detectedBackend = detectBackendFromLocation(sendableModel) {
            metadata["detectedBackend"] = detectedBackend.rawValue
        }

        return metadata
    }

    /// Check if a ModelInfo was created from a specific SendableModel
    /// 
    /// - Parameters:
    ///   - modelInfo: ModelInfo to check
    ///   - sendableModel: SendableModel to match against
    /// - Returns: True if the ModelInfo corresponds to the SendableModel
    public static func isAssociated(modelInfo: ModelInfo, with sendableModel: SendableModel) -> Bool {
        // Primary check: UUID match
        if modelInfo.id == sendableModel.id {
            return true
        }

        // Secondary check: metadata match
        if let storedId = modelInfo.metadata["sendableModelId"],
           storedId == sendableModel.id.uuidString {
            return true
        }

        return false
    }
}
