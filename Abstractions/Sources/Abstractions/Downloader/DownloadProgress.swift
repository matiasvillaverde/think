import Foundation

/// Enhanced download progress with byte-based accuracy
public struct DownloadProgress: Sendable, Equatable {
    public let bytesDownloaded: Int64
    public let totalBytes: Int64
    public let filesCompleted: Int
    public let totalFiles: Int
    public let currentFileName: String?

    public init(
        bytesDownloaded: Int64,
        totalBytes: Int64,
        filesCompleted: Int,
        totalFiles: Int,
        currentFileName: String? = nil
    ) {
        self.bytesDownloaded = bytesDownloaded
        self.totalBytes = totalBytes
        self.filesCompleted = filesCompleted
        self.totalFiles = totalFiles
        self.currentFileName = currentFileName
    }

    /// Progress as a fraction from 0.0 to 1.0
    public var fractionCompleted: Double {
        guard totalBytes > 0 else {
            return 0
        }

        return Double(bytesDownloaded) / Double(totalBytes)
    }

    /// Progress as a percentage from 0 to 100
    public var percentage: Double {
        let percentageMultiplier: Double = 100
        return fractionCompleted * percentageMultiplier
    }

    /// Whether the download is complete
    public var isComplete: Bool {
        bytesDownloaded >= totalBytes && filesCompleted >= totalFiles
    }

    /// Human-readable description of progress
    public var description: String {
        let bytesText: String = ByteCountFormatter.string(
            fromByteCount: bytesDownloaded,
            countStyle: .file
        )
        let totalText: String = ByteCountFormatter.string(
            fromByteCount: totalBytes,
            countStyle: .file
        )
        let fileText: String = "\(filesCompleted)/\(totalFiles) files"

        if let currentFileName {
            let formatString: String = "%.1f"
            let percentageText: String = String(format: formatString, percentage)
            return "\(bytesText)/\(totalText) (\(percentageText)%) - \(fileText) - " +
                "\(currentFileName)"
        }

        let formatString: String = "%.1f"
        let percentageText: String = String(format: formatString, percentage)
        return "\(bytesText)/\(totalText) (\(percentageText)%) - \(fileText)"
    }

    // MARK: - Factory Methods

    /// Creates an initial progress state
    public static func initial(totalBytes: Int64, totalFiles: Int) -> Self {
        Self(
            bytesDownloaded: 0,
            totalBytes: totalBytes,
            filesCompleted: 0,
            totalFiles: totalFiles
        )
    }

    /// Creates a completed progress state
    public static func completed(totalBytes: Int64, totalFiles: Int) -> Self {
        Self(
            bytesDownloaded: totalBytes,
            totalBytes: totalBytes,
            filesCompleted: totalFiles,
            totalFiles: totalFiles
        )
    }

    /// Updates progress with new byte count
    public func updating(
        bytesDownloaded: Int64,
        currentFileName: String? = nil
    ) -> Self {
        Self(
            bytesDownloaded: bytesDownloaded,
            totalBytes: totalBytes,
            filesCompleted: filesCompleted,
            totalFiles: totalFiles,
            currentFileName: currentFileName
        )
    }

    /// Updates progress when a file is completed
    public func completingFile() -> Self {
        Self(
            bytesDownloaded: bytesDownloaded,
            totalBytes: totalBytes,
            filesCompleted: filesCompleted + 1,
            totalFiles: totalFiles,
            currentFileName: nil
        )
    }
}
