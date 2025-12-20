import Abstractions
import Foundation

/// Utility for managing model file paths
public struct ModelPath: Sendable {
    internal let baseDirectory: URL

    /// Default models directory in the user's Application Support
    public static var defaultModelsDirectory: URL {
        let appSupport: URL = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first ?? URL(fileURLWithPath: NSTemporaryDirectory())
        return appSupport.appendingPathComponent("ThinkAI/Models", isDirectory: true)
    }

    /// Temporary downloads directory
    public static var defaultTemporaryDirectory: URL {
        let temp: URL = FileManager.default.temporaryDirectory
        return temp.appendingPathComponent("ThinkAI/Downloads", isDirectory: true)
    }

    // MARK: - Path Generation

    /// Get directory for a specific model backend
    internal func backendDirectory(for backend: SendableModel.Backend) -> URL {
        baseDirectory.appendingPathComponent(backend.directoryName, isDirectory: true)
    }

    /// Get directory for a specific model
    internal func modelDirectory(for modelId: UUID, backend: SendableModel.Backend) -> URL {
        backendDirectory(for: backend)
            .appendingPathComponent(modelId.uuidString, isDirectory: true)
    }

    /// Get temporary directory for a download
    internal func temporaryDirectory(for modelId: UUID) -> URL {
        baseDirectory
            .appendingPathComponent(modelId.uuidString, isDirectory: true)
    }

    /// Get model info file path
    internal func modelInfoFile(for modelId: UUID, backend: SendableModel.Backend) -> URL {
        modelDirectory(for: modelId, backend: backend)
            .appendingPathComponent("model_info.json")
    }

    // MARK: - Validation

    /// Validate that a path is within the expected models directory
    internal func isValidModelPath(_ url: URL) -> Bool {
        let resolvedBase: URL = baseDirectory.resolvingSymlinksInPath()
        let resolvedPath: URL = url.resolvingSymlinksInPath()
        return resolvedPath.path.hasPrefix(resolvedBase.path)
    }

    /// Extract model ID from a path if possible
    internal func extractModelId(from url: URL) -> UUID? {
        let components: [String] = url.pathComponents

        // Look for a UUID string in the path components
        for component in components {
            if let uuid: UUID = UUID(uuidString: component) {
                return uuid
            }
        }

        return nil
    }
}
