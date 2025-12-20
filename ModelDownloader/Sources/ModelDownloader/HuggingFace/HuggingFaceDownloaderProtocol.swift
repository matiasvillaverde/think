import Abstractions
import Foundation
import ZIPFoundation

/// Protocol for downloading models from HuggingFace Hub
internal protocol HuggingFaceDownloaderProtocol: Sendable {
    /// Download a model from HuggingFace Hub
    func download(
        modelId: String,
        backend: SendableModel.Backend,
        customId: UUID?
    ) -> AsyncThrowingStream<DownloadEvent, Error>

    /// Cancel an ongoing download
    func cancelDownload(for modelId: String) async

    /// Pause an ongoing download
    func pauseDownload(for modelId: String) async

    /// Resume a paused download
    func resumeDownload(for modelId: String) async

    /// Check if model exists on HuggingFace Hub
    func modelExists(modelId: String) async throws -> Bool

    /// Get model metadata without downloading
    func getModelMetadata(modelId: String, backend: SendableModel.Backend) async throws -> [FileMetadata]

    /// Get model files information for background downloads
    func getModelFiles(modelId: String, backend: SendableModel.Backend) async throws -> [FileDownloadInfo]
}

// MARK: - Supporting Types

private struct HuggingFaceFile: Decodable {
    let path: String
    let size: Int64?
    let oid: String?
    let type: String
}

internal enum HuggingFaceError: Error, LocalizedError, Sendable {
    case authenticationRequired
    case downloadFailed
    case downloadFailedWithError(Error)
    case insufficientSpace
    case invalidResponse
    case modelNotFound
    case repositoryNotFound
    case fileNotFound
    case httpError(statusCode: Int)
    case invalidURL
    case diskSpaceInsufficient
    case invalidFormat
    case timeout
    case networkError(Error)
    case insufficientDiskSpace
    case invalidModel
    case unsupportedFormat
    case configurationMissing

    internal var errorDescription: String? {
        switch self {
        case .authenticationRequired:
            return "Authentication required for this model"

        case .downloadFailed:
            return "Download failed"

        case .insufficientSpace:
            return "Insufficient disk space for download"

        case .invalidResponse:
            return "Invalid response from HuggingFace API"

        case .modelNotFound:
            return "Model not found on HuggingFace Hub"

        case .repositoryNotFound:
            return "Repository not found on HuggingFace Hub"

        case .fileNotFound:
            return "File not found in repository"

        case .httpError(let statusCode):
            return "HTTP error with status code: \(statusCode)"

        case .invalidURL:
            return "Invalid URL"

        case .diskSpaceInsufficient:
            return "Insufficient disk space"

        case .invalidFormat:
            return "Invalid format"

        case .downloadFailedWithError(let error):
            return "Download failed: \(error.localizedDescription)"

        case .timeout:
            return "Request timed out"

        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"

        case .insufficientDiskSpace:
            return "Insufficient disk space for download"

        case .invalidModel:
            return "Invalid model configuration"

        case .unsupportedFormat:
            return "Unsupported model format"

        case .configurationMissing:
            return "Model configuration file missing"
        }
    }
}

// MARK: - String Extensions

extension String {
    func matches(glob pattern: String) -> Bool {
        // Simple glob matching for common patterns
        if pattern.hasPrefix("*.") {
            let globPrefixLength: Int = 2
            let suffix: String = String(pattern.dropFirst(globPrefixLength))
            return self.hasSuffix(suffix)
        }

        return self == pattern
    }
}
