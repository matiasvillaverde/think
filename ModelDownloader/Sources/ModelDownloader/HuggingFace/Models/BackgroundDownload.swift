import Abstractions
import Foundation

// MARK: - BackgroundDownloadHandle Extensions

extension BackgroundDownloadHandle {
    /// Cancel this background download
    public func cancel() async {
        await BackgroundDownloadManager.shared.cancelDownload(id: id)
    }

    /// Get current progress (if app is active and download is ongoing)
    public func progress() -> DownloadProgress? {
        BackgroundDownloadManager.shared.getDownloadProgress(id: id)
    }
}

// MARK: - BackgroundDownloadPriority Extensions

extension BackgroundDownloadPriority {
    /// Convert to URLSessionTask priority
    internal var urlSessionPriority: Float {
        switch self {
        case .low:
            return URLSessionTask.lowPriority

        case .normal:
            return URLSessionTask.defaultPriority

        case .high:
            return URLSessionTask.highPriority
        }
    }
}

/// Internal model for persisting download state across app sessions
internal struct PersistedDownload: Sendable, Codable {
    /// Unique download identifier
    let id: UUID

    /// HuggingFace model identifier
    let modelId: String

    /// Model backend
    let backend: SendableModel.Backend

    /// Background session identifier
    let sessionIdentifier: String

    /// URLSession task identifier (nil if not yet started)
    let taskIdentifier: Int?

    /// When download was created
    let downloadDate: Date

    /// Expected files to download
    let expectedFiles: [String]

    /// Files that have been completed
    let completedFiles: [String]

    /// Full file information for downloads (URL, size, paths)
    let fileDownloads: [BackgroundFileDownload]

    /// Download configuration options
    let options: BackgroundDownloadOptions

    /// Total expected bytes
    let totalBytes: Int64

    /// Bytes downloaded so far
    let bytesDownloaded: Int64

    /// Current download state
    let state: DownloadState

    /// Warnings collected during download
    let warnings: [String]

    internal init(
        id: UUID,
        modelId: String,
        backend: SendableModel.Backend,
        sessionIdentifier: String,
        options: BackgroundDownloadOptions,
        taskIdentifier: Int? = nil,
        downloadDate: Date = Date(),
        expectedFiles: [String] = [],
        completedFiles: [String] = [],
        fileDownloads: [BackgroundFileDownload] = [],
        totalBytes: Int64 = 0,
        bytesDownloaded: Int64 = 0,
        state: DownloadState = .pending,
        warnings: [String] = []
    ) {
        self.id = id
        self.modelId = modelId
        self.backend = backend
        self.sessionIdentifier = sessionIdentifier
        self.taskIdentifier = taskIdentifier
        self.downloadDate = downloadDate
        self.expectedFiles = expectedFiles
        self.completedFiles = completedFiles
        self.fileDownloads = fileDownloads
        self.options = options
        self.totalBytes = totalBytes
        self.bytesDownloaded = bytesDownloaded
        self.state = state
        self.warnings = warnings
    }

    /// Create BackgroundDownloadHandle from persisted download
    internal func toHandle() -> BackgroundDownloadHandle {
        BackgroundDownloadHandle(
            id: id,
            modelId: modelId,
            backend: backend,
            sessionIdentifier: sessionIdentifier
        )
    }

    /// Update download progress
    internal func updatingProgress(
        bytesDownloaded: Int64,
        completedFiles: [String] = [],
        state: DownloadState? = nil,
        taskIdentifier: Int? = nil,
        warnings: [String]? = nil
    ) -> Self {
        Self(
            id: id,
            modelId: modelId,
            backend: backend,
            sessionIdentifier: sessionIdentifier,
            options: options,
            taskIdentifier: taskIdentifier ?? self.taskIdentifier,
            downloadDate: downloadDate,
            expectedFiles: expectedFiles,
            completedFiles: completedFiles.isEmpty ? self.completedFiles : completedFiles,
            fileDownloads: fileDownloads,
            totalBytes: totalBytes,
            bytesDownloaded: bytesDownloaded,
            state: state ?? self.state,
            warnings: warnings ?? self.warnings
        )
    }

    /// Add a warning to this download
    internal func addingWarning(_ warning: String) -> Self {
        var newWarnings: [String] = self.warnings
        newWarnings.append(warning)
        return updatingProgress(
            bytesDownloaded: bytesDownloaded,
            warnings: newWarnings
        )
    }
}
