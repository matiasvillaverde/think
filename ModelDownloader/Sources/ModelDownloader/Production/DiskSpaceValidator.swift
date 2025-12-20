import Abstractions
import Foundation

/// Protocol for file system operations (for testing)
internal protocol FileSystemProtocol: Sendable {
    func getFreeSpace(forPath path: String) async throws -> Int64?
}

/// Default file system implementation
internal struct DefaultFileSystem: FileSystemProtocol {
    internal func getFreeSpace(forPath path: String) throws -> Int64? {
        let attributes: [FileAttributeKey: Any] = try FileManager.default.attributesOfFileSystem(forPath: path)
        return attributes[.systemFreeSize] as? Int64
    }
}

/// Validates available disk space before downloads
internal actor DiskSpaceValidator {
    private let fileManager: any FileSystemProtocol
    private let minimumFreeSpaceMultiplier: Double
    private let logger: ModelDownloaderLogger = ModelDownloaderLogger(
        subsystem: "com.modeldownloader",
        category: "diskspace"
    )

    /// Initialize disk space validator
    /// - Parameters:
    ///   - fileManager: File system interface (for testing)
    ///   - minimumFreeSpaceMultiplier: Multiplier for required free space (default 1.5x)
    internal init(
        fileManager: (any FileSystemProtocol)? = nil,
        minimumFreeSpaceMultiplier: Double = 1.5
    ) {
        self.fileManager = fileManager ?? DefaultFileSystem()
        self.minimumFreeSpaceMultiplier = max(1.0, minimumFreeSpaceMultiplier)
    }

    /// Check if there's enough disk space for download
    /// - Parameters:
    ///   - requiredBytes: Number of bytes needed for download
    ///   - url: Target location for download
    /// - Returns: true if there's enough space
    internal func hasEnoughSpace(
        for requiredBytes: Int64,
        at url: URL
    ) async throws -> Bool {
        guard let availableBytes: Int64 = try await fileManager.getFreeSpace(forPath: url.path) else {
            await logger.warning("Unable to determine free disk space")
            return true // Proceed if we can't determine space
        }
        let requiredWithBuffer: Int64 = Int64(Double(requiredBytes) * minimumFreeSpaceMultiplier)

        let hasSpace: Bool = availableBytes >= requiredWithBuffer

        if hasSpace {
            await logger.debug(
                "Disk space check passed: \(formatBytes(availableBytes)) available, " +
                "\(formatBytes(requiredWithBuffer)) required"
            )
        } else {
            await logger.warning(
                "Insufficient disk space: \(formatBytes(availableBytes)) available, " +
                "\(formatBytes(requiredWithBuffer)) required"
            )
        }

        return hasSpace
    }

    /// Validate space for multiple files
    /// - Parameters:
    ///   - files: Array of files with size information
    ///   - destination: Target directory for downloads
    /// - Returns: true if there's enough space for all files
    internal func hasEnoughSpace(
        for files: [FileDownloadInfo],
        at destination: URL
    ) async throws -> Bool {
        let totalSize: Int64 = files.reduce(0) { $0 + $1.size }
        return try await hasEnoughSpace(for: totalSize, at: destination)
    }

    // MARK: - Private Helpers

    private func formatBytes(_ bytes: Int64) -> String {
        let formatter: ByteCountFormatter = ByteCountFormatter()
        formatter.countStyle = .binary
        return formatter.string(fromByteCount: bytes)
    }
}

/// Extension to validate disk space before download
extension DownloadCoordinator {
    /// Download files with disk space validation
    /// - Parameters:
    ///   - files: Files to download
    ///   - destination: Target directory
    ///   - headers: HTTP headers
    ///   - validateSpace: Whether to validate disk space first
    ///   - progressHandler: Progress callback
    /// - Returns: Download results
    func downloadFilesWithValidation(
        _ files: [FileDownloadInfo],
        to destination: URL,
        headers: [String: String],
        validateSpace: Bool = true,
        progressHandler: @escaping @Sendable (DownloadProgress) -> Void
    ) async throws -> [DownloadResult] {
        if validateSpace {
            let validator: DiskSpaceValidator = DiskSpaceValidator()
            let hasSpace: Bool = try await validator.hasEnoughSpace(
                for: files,
                at: destination
            )

            if !hasSpace {
                throw HuggingFaceError.insufficientDiskSpace
            }
        }

        return try await downloadFiles(
            files,
            headers: headers,
            progressHandler: progressHandler
        )
    }
}
