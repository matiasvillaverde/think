import Foundation

/// Strategy for loading RAG AI models
public enum RagLoadingStrategy: Sendable {
    /// Load model immediately during initialization (current behavior)
    case eager
    /// Load model only when first accessed (memory optimization)
    case lazy
    /// Load model after a specified delay
    case hybrid(preloadAfter: TimeInterval)

    public var debugDescription: String {
        switch self {
        case .eager:
            return "Eager loading - model loaded immediately"
        case .lazy:
            return "Lazy loading - model loaded on first use"
        case .hybrid(let delay):
            return "Hybrid loading - model preloaded after \(delay)s"
        }
    }
}
