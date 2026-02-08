import Foundation

/// Common error patterns and their user-friendly descriptions
public enum ModelDownloadError: LocalizedError, Sendable, Equatable {
    case incompatibleFormat(SendableModel.ModelType, SendableModel.Backend)
    case repositoryNotFound(String)
    case insufficientMemory(required: UInt64, available: UInt64)
    case networkConnectivityRequired
    case backgroundDownloadUnsupported
    case modelAlreadyDownloaded(UUID)
    case invalidRepositoryIdentifier(String)
    case networkError(Error)
    case insufficientStorage(required: UInt64, available: UInt64)
    case modelNotFound(UUID)
    case invalidURL(String)
    case downloadCancelled
    case checksumMismatch(expected: String, actual: String)
    case serverError(statusCode: Int)
    case fileSystemError(Error)
    case unknown(String)

    public var errorDescription: String? {
        switch self {
        case let .incompatibleFormat(modelType, backend):
            return "Model type '\(modelType.rawValue)' is not compatible with backend '\(backend.rawValue)'"

        case let .repositoryNotFound(repoId):
            return "Repository '\(repoId)' not found on HuggingFace Hub"

        case let .insufficientMemory(required, available):
            let requiredGB = Double(required) / 1_000_000_000
            let availableGB = Double(available) / 1_000_000_000
            return String(format: "Insufficient RAM: %.1fGB required, %.1fGB available", requiredGB, availableGB)

        case .networkConnectivityRequired:
            return "Network connection required for downloading models"

        case .backgroundDownloadUnsupported:
            return "Background downloads are not supported on this platform"

        case .modelAlreadyDownloaded(let uuid):
            return "Model \(uuid.uuidString) is already downloaded"

        case .invalidRepositoryIdentifier(let repoId):
            return "Invalid repository identifier: '\(repoId)'"

        case .networkError:
            return "Network connection error"

        case .insufficientStorage:
            return "Insufficient storage space"

        case .modelNotFound:
            return "Model not found"

        case .invalidURL:
            return "Invalid download URL"

        case .downloadCancelled:
            return "Download cancelled"

        case .checksumMismatch:
            return "Download verification failed"

        case .serverError(let statusCode):
            return "Server error (\(statusCode))"

        case .fileSystemError:
            return "File system error"

        case .unknown(let message):
            return "Unknown error: \(message)"
        }
    }

    public var recoverySuggestion: String? {
        switch self {
        case .incompatibleFormat(let modelType, _):
            switch modelType {
            case .diffusion, .diffusionXL:
                return "Try using CoreML format for diffusion models"
            case .language, .deepLanguage, .flexibleThinker:
                return "Try using MLX or GGUF format for language models"
            case .visualLanguage:
                return "Try using MLX format for visual language models"
            }

        case .repositoryNotFound:
            return "Check the repository name and ensure it exists on HuggingFace Hub"

        case .insufficientMemory:
            return "Close other applications or try a smaller model variant"

        case .networkConnectivityRequired:
            return "Connect to WiFi or cellular network and try again"

        case .backgroundDownloadUnsupported:
            return "Use foreground download mode instead"

        case .modelAlreadyDownloaded:
            return "The model is already available for use"

        case .invalidRepositoryIdentifier:
            return "Repository ID should be in format 'owner/repository' (e.g., 'microsoft/DialoGPT-medium')"

        case .networkError:
            return "Please check your internet connection and try again"

        case let .insufficientStorage(required, available):
            let formatter = ByteCountFormatter()
            formatter.countStyle = .file
            let requiredStr = formatter.string(fromByteCount: Int64(required))
            let availableStr = formatter.string(fromByteCount: Int64(available))
            return "This download requires \(requiredStr) but only \(availableStr) is available"

        case .modelNotFound:
            return "The requested model could not be found"

        case .invalidURL:
            return "The download URL is malformed"

        case .downloadCancelled:
            return "The download was cancelled by user request"

        case .checksumMismatch:
            return "The downloaded file is corrupted. Please try downloading again"

        case .serverError:
            return "The server is temporarily unavailable. Please try again later"

        case .fileSystemError:
            return "Unable to save the downloaded file"

        case .unknown(let message):
            return message
        }
    }

    /// Whether this error is potentially recoverable by retrying
    public var isRetryable: Bool {
        switch self {
        case .networkError, .downloadCancelled, .checksumMismatch, .serverError, .networkConnectivityRequired:
            return true
        case .insufficientStorage, .insufficientMemory, .modelNotFound, .invalidURL,
             .invalidRepositoryIdentifier, .repositoryNotFound, .modelAlreadyDownloaded,
             .incompatibleFormat, .fileSystemError, .unknown, .backgroundDownloadUnsupported:
            return false
        }
    }
}

// MARK: - Equatable

extension ModelDownloadError {
    /// Compares two ModelDownloadError instances for equality
    /// - Parameters:
    ///   - lhs: The left-hand side error
    ///   - rhs: The right-hand side error
    /// - Returns: True if the errors are equal
    public static func == (lhs: ModelDownloadError, rhs: ModelDownloadError) -> Bool {
        switch (lhs, rhs) {
        case (.networkConnectivityRequired, .networkConnectivityRequired),
             (.backgroundDownloadUnsupported, .backgroundDownloadUnsupported),
             (.downloadCancelled, .downloadCancelled):
            return true

        case let (.incompatibleFormat(lhsType, lhsBackend), .incompatibleFormat(rhsType, rhsBackend)):
            return lhsType == rhsType && lhsBackend == rhsBackend

        case let (.repositoryNotFound(lhsRepo), .repositoryNotFound(rhsRepo)):
            return lhsRepo == rhsRepo

        case let (.insufficientMemory(lhsReq, lhsAvail), .insufficientMemory(rhsReq, rhsAvail)):
            return lhsReq == rhsReq && lhsAvail == rhsAvail

        case let (.insufficientStorage(lhsReq, lhsAvail), .insufficientStorage(rhsReq, rhsAvail)):
            return lhsReq == rhsReq && lhsAvail == rhsAvail

        case let (.modelAlreadyDownloaded(lhsId), .modelAlreadyDownloaded(rhsId)):
            return lhsId == rhsId

        case let (.invalidRepositoryIdentifier(lhsId), .invalidRepositoryIdentifier(rhsId)):
            return lhsId == rhsId

        case let (.modelNotFound(lhsId), .modelNotFound(rhsId)):
            return lhsId == rhsId

        case let (.invalidURL(lhsURL), .invalidURL(rhsURL)):
            return lhsURL == rhsURL

        case let (.checksumMismatch(lhsExp, lhsAct), .checksumMismatch(rhsExp, rhsAct)):
            return lhsExp == rhsExp && lhsAct == rhsAct

        case let (.serverError(lhsCode), .serverError(rhsCode)):
            return lhsCode == rhsCode

        case let (.networkError(lhsError), .networkError(rhsError)):
            return (lhsError as NSError) == (rhsError as NSError)

        case let (.fileSystemError(lhsError), .fileSystemError(rhsError)):
            return (lhsError as NSError) == (rhsError as NSError)

        case let (.unknown(lhsMsg), .unknown(rhsMsg)):
            return lhsMsg == rhsMsg

        default:
            return false
        }
    }
}
