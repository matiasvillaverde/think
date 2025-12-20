import Foundation

/// Struct to hold platform-specific directories for models
internal struct ModelDirectories {
    /// Directory for DeepSeek model
    internal let deepSeekModelDir: String?

    /// Hugging Face repository for DeepSeek
    internal let deepSeekHuggingFace: String?

    /// Returns platform-specific directories for models
    internal static func getPlatformDirectories() -> ModelDirectories {
        #if os(iOS) || os(visionOS)
        return ModelDirectories(
            deepSeekModelDir: nil,
            deepSeekHuggingFace: "mlx-community/DeepSeek-R1-Distill-Qwen-7B-4bit"
        )
        #else
        return ModelDirectories(
            deepSeekModelDir: nil,
            deepSeekHuggingFace: "mlx-community/DeepSeek-R1-Distill-Qwen-32B-4bit"
        )
        #endif
    }
}
