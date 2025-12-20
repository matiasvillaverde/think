import Abstractions
import Foundation

/// Factory for creating MLXSession instances
public enum MLXSessionFactory {
    /// Create a new MLXSession with the given configuration
    /// - Parameter configuration: Provider configuration with model location and settings
    /// - Returns: An LLMSession instance backed by MLX
    public static func create() -> LLMSession {
        MLXSession()
    }
}
