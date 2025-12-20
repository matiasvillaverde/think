import Abstractions
import Foundation

/// Factory for creating appropriate file selectors based on model backend
internal actor FileSelectorFactory {
    private let logger: ModelDownloaderLogger = ModelDownloaderLogger(
        subsystem: "com.think.modeldownloader",
        category: "FileSelectorFactory"
    )

    /// Shared instance of the factory
    internal static let shared: FileSelectorFactory = FileSelectorFactory()

    /// Private initializer to enforce singleton
    private init() {}

    /// Create appropriate file selector based on backend
    /// - Parameter backend: The model backend type
    /// - Returns: Appropriate file selector or nil if no selection needed
    internal func createSelector(for backend: SendableModel.Backend) async -> FileSelectorProtocol? {
        switch backend {
        case .coreml:
            await logger.debug("Creating CoreML file selector")
            return CoreMLFileSelectorAdapter()

        case .gguf:
            await logger.debug("Creating GGUF file selector")
            return GGUFFileSelectorAdapter()

        case .mlx:
            await logger.debug("Creating MLX file selector")
            return MLXFileSelectorAdapter()
        }
    }
}
