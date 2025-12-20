import Abstractions
import Foundation
import os

/// Centralized logging for ModelDownloader
internal actor ModelDownloaderLogger {
    private let logger: Logger
    private let subsystem: String
    private let category: String

    /// Log level for filtering
    internal enum Level: Int, Comparable {
        case debug = 0
        case info = 1
        case warning = 2
        case error = 3

        internal static func < (lhs: Level, rhs: Level) -> Bool {
            lhs.rawValue < rhs.rawValue
        }
    }

    private var minimumLevel: Level = .info

    /// Initialize logger
    /// - Parameters:
    ///   - subsystem: Subsystem identifier (e.g., "com.modeldownloader")
    ///   - category: Category for this logger instance
    internal init(subsystem: String, category: String) {
        self.subsystem = subsystem
        self.category = category
        self.logger = Logger(subsystem: subsystem, category: category)
    }

    /// Set minimum log level
    internal func setMinimumLevel(_ level: Level) {
        minimumLevel = level
    }

    /// Log debug message
    internal func debug(_ message: String, metadata: [String: Any]? = nil) {
        guard minimumLevel <= .debug else { return }

        if let metadata {
            logger.debug("\(message, privacy: .public) | \(self.formatMetadata(metadata), privacy: .public)")
        } else {
            logger.debug("\(message, privacy: .public)")
        }
    }

    /// Log info message
    internal func info(_ message: String, metadata: [String: Any]? = nil) {
        guard minimumLevel <= .info else { return }

        if let metadata {
            logger.info("\(message, privacy: .public) | \(self.formatMetadata(metadata), privacy: .public)")
        } else {
            logger.info("\(message, privacy: .public)")
        }
    }

    /// Log warning message
    internal func warning(_ message: String, error: Error? = nil, metadata: [String: Any]? = nil) {
        guard minimumLevel <= .warning else { return }

        var combinedMetadata: [String: Any] = metadata ?? [:]
        if let error {
            combinedMetadata["error"] = String(describing: error)
        }

        if !combinedMetadata.isEmpty {
            logger.warning("\(message, privacy: .public) | \(self.formatMetadata(combinedMetadata), privacy: .public)")
        } else {
            logger.warning("\(message, privacy: .public)")
        }
    }

    /// Log error message
    internal func error(_ message: String, error: Error? = nil, metadata: [String: Any]? = nil) {
        guard minimumLevel <= .error else { return }

        var combinedMetadata: [String: Any] = metadata ?? [:]
        if let error {
            combinedMetadata["error"] = String(describing: error)
            combinedMetadata["errorType"] = String(describing: type(of: error))
        }

        if !combinedMetadata.isEmpty {
            logger.error("\(message, privacy: .public) | \(self.formatMetadata(combinedMetadata), privacy: .public)")
        } else {
            logger.error("\(message, privacy: .public)")
        }
    }

    /// Log synchronously - for use in non-async contexts like URLSession delegates
    /// CRITICAL: This is needed for file handling in download delegates
    nonisolated func logSync(_ message: String, error: Error? = nil, metadata: [String: Any]? = nil) {
         let logger: Logger = Logger(subsystem: subsystem, category: category)

        var combinedMetadata: [String: Any] = metadata ?? [:]
        if let error {
            combinedMetadata["error"] = String(describing: error)
        }

        let formattedMetadata: String = combinedMetadata.map { "\($0.key)=\($0.value)" }.joined(separator: ", ")

        if !formattedMetadata.isEmpty {
            logger.info("\(message, privacy: .public) | \(formattedMetadata, privacy: .public)")
        } else {
            logger.info("\(message, privacy: .public)")
        }
    }

    /// Log download start
    internal func logDownloadStart(
        modelId: String,
        backend: SendableModel.Backend,
        totalSize: Int64? = nil
    ) {
        var metadata: [String: Any] = [
            "modelId": modelId,
            "backend": backend.rawValue
        ]

        if let size = totalSize {
            metadata["totalSize"] = formatBytes(size)
        }

        info("Starting model download", metadata: metadata)
    }

    /// Log download progress
    internal func logDownloadProgress(
        modelId: String,
        progress: DownloadProgress
    ) {
        let metadata: [String: Any] = [
            "modelId": modelId,
            "percentage": String(format: "%.1f%%", progress.percentage),
            "downloaded": formatBytes(progress.bytesDownloaded),
            "total": formatBytes(progress.totalBytes),
            "filesCompleted": "\(progress.filesCompleted)/\(progress.totalFiles)"
        ]

        debug("Download progress", metadata: metadata)
    }

    /// Log download completion
    internal func logDownloadComplete(
        modelId: String,
        duration: TimeInterval,
        totalSize: Int64
    ) {
        let metadata: [String: Any] = [
            "modelId": modelId,
            "duration": formatDuration(duration),
            "totalSize": formatBytes(totalSize),
            "averageSpeed": formatSpeed(totalSize, duration: duration)
        ]

        info("Download completed successfully", metadata: metadata)
    }

    /// Log API request
    internal func logAPIRequest(
        method: String,
        url: URL,
        headers: [String: String]? = nil
    ) {
        var metadata: [String: Any] = [
            "method": method,
            "url": url.absoluteString
        ]

        // Log headers but redact auth tokens
        if let headers {
            let redactedHeaders: [String: String] = headers.mapValues { value in
                if value.lowercased().starts(with: "bearer ") {
                    return "Bearer [REDACTED]"
                }
                return value
            }
            metadata["headers"] = redactedHeaders
        }

        debug("API request", metadata: metadata)
    }

    /// Log API response
    internal func logAPIResponse(
        url: URL,
        statusCode: Int,
        duration: TimeInterval
    ) {
        let metadata: [String: Any] = [
            "url": url.absoluteString,
            "statusCode": statusCode,
            "duration": String(format: "%.3fs", duration)
        ]

        if statusCode >= 200, statusCode < 300 {
            debug("API response", metadata: metadata)
        } else {
            warning("API response error", metadata: metadata)
        }
    }

    // MARK: - Private Helpers

    private func formatMetadata(_ metadata: [String: Any]) -> String {
        metadata.map { "\($0.key)=\($0.value)" }.joined(separator: ", ")
    }

    private func formatBytes(_ bytes: Int64) -> String {
        let formatter: ByteCountFormatter = ByteCountFormatter()
        formatter.countStyle = .binary
        return formatter.string(fromByteCount: bytes)
    }

    private func formatDuration(_ duration: TimeInterval) -> String {
        if duration < 60 {
            return String(format: "%.1fs", duration)
        }
        if duration < 3_600 {
            let minutes: Int = Int(duration / 60)
            let seconds: Int = Int(duration.truncatingRemainder(dividingBy: 60))
            return "\(minutes)m \(seconds)s"
        }
        let hours: Int = Int(duration / 3_600)
        let minutes: Int = Int((duration.truncatingRemainder(dividingBy: 3_600)) / 60)
        return "\(hours)h \(minutes)m"
    }

    private func formatSpeed(_ bytes: Int64, duration: TimeInterval) -> String {
        guard duration > 0 else { return "N/A" }
        let bytesPerSecond: Double = Double(bytes) / duration
        let formatter: ByteCountFormatter = ByteCountFormatter()
        formatter.countStyle = .binary
        return "\(formatter.string(fromByteCount: Int64(bytesPerSecond)))/s"
    }
}

/// Global logger instance
internal let kModelDownloaderLogger: ModelDownloaderLogger = ModelDownloaderLogger(
    subsystem: "ModelDownloader",
    category: "general"
)
