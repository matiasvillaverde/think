import Foundation

/// Mock error for testing ModelDownloader failures
public enum MockModelDownloaderError: LocalizedError, Sendable {
    case downloadFailed
    case downloadNotSupported

    public var errorDescription: String? {
        switch self {
        case .downloadFailed:
            return "Mock download failed"
        case .downloadNotSupported:
            return "Mock download not supported"
        }
    }
}
