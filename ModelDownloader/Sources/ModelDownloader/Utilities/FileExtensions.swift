import Foundation

/// Common file and directory extensions used throughout ModelDownloader
extension URL {
    /// Check if this URL represents a directory
    var isDirectory: Bool {
        (try? resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory ?? false
    }

    /// Get file size in bytes, returns nil if file doesn't exist or is a directory
    var fileSize: Int64? {
        guard let values = try? resourceValues(forKeys: [.isDirectoryKey, .fileSizeKey]),
              values.isDirectory != true,
              let size = values.fileSize else {
            return nil
        }
        return Int64(size)
    }

    /// Get total size of directory including all subdirectories
    func directorySize() -> Int64 {
        guard isDirectory else {
            return fileSize ?? 0
        }

        let fileManager: FileManager = FileManager.default
        guard let enumerator = fileManager.enumerator(
            at: self,
            includingPropertiesForKeys: [.fileSizeKey, .isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else {
            return 0
        }

        var totalSize: Int64 = 0
        while let url = enumerator.nextObject() as? URL {
            if let size = url.fileSize {
                totalSize += size
            }
        }
        return totalSize
    }

    /// Check if file exists and is not a directory
    var isRegularFile: Bool {
        var isDir: ObjCBool = false
        let exists: Bool = FileManager.default.fileExists(atPath: path, isDirectory: &isDir)
        return exists && !isDir.boolValue
    }

    /// Get human-readable file extension (e.g., "mlmodelc" instead of "MLMODELC")
    var normalizedPathExtension: String {
        pathExtension.lowercased()
    }

    /// Check if this is a ZIP file based on extension
    var isZipFile: Bool {
        normalizedPathExtension == "zip"
    }

    /// Check if this is a CoreML model file
    var isCoreMLModel: Bool {
        let ext: String = normalizedPathExtension
        return ext == "mlmodel" || ext == "mlmodelc" || ext == "mlpackage"
    }

    /// Get modification date of file
    var modificationDate: Date? {
        (try? resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate
    }

    /// Create directory at this URL if it doesn't exist
    func createDirectoryIfNeeded() throws {
        let fileManager: FileManager = FileManager.default
        if !fileManager.fileExists(atPath: path) {
            try fileManager.createDirectory(at: self, withIntermediateDirectories: true)
        }
    }

    /// Remove file or directory if it exists
    func removeIfExists() throws {
        let fileManager: FileManager = FileManager.default
        if fileManager.fileExists(atPath: path) {
            try fileManager.removeItem(at: self)
        }
    }

    /// List all files in directory (non-recursive)
    func listFiles(includeHidden: Bool = false) throws -> [URL] {
        let fileManager: FileManager = FileManager.default
        return try fileManager.contentsOfDirectory(
            at: self,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: includeHidden ? [] : [.skipsHiddenFiles]
        )
        .filter { !$0.isDirectory }
    }

    /// List all subdirectories (non-recursive)
    func listDirectories(includeHidden: Bool = false) throws -> [URL] {
        let fileManager: FileManager = FileManager.default
        return try fileManager.contentsOfDirectory(
            at: self,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: includeHidden ? [] : [.skipsHiddenFiles]
        )
        .filter(\.isDirectory)
    }
}

/// Extensions for FileManager
extension FileManager {
    /// Check if directory exists at path
    func directoryExists(at url: URL) -> Bool {
        var isDir: ObjCBool = false
        return fileExists(atPath: url.path, isDirectory: &isDir) && isDir.boolValue
    }

    /// Move file with automatic directory creation
    func moveItemCreatingIntermediateDirectories(at source: URL, to destination: URL) throws {
        // Create destination directory if needed
        try destination.deletingLastPathComponent().createDirectoryIfNeeded()

        // Remove destination if it exists
        try destination.removeIfExists()

        // Move the file
        try moveItem(at: source, to: destination)
    }

    /// Copy file with automatic directory creation
    func copyItemCreatingIntermediateDirectories(at source: URL, to destination: URL) throws {
        // Create destination directory if needed
        try destination.deletingLastPathComponent().createDirectoryIfNeeded()

        // Remove destination if it exists
        try destination.removeIfExists()

        // Copy the file
        try copyItem(at: source, to: destination)
    }
}

/// Byte formatting utilities
extension Int64 {
    /// Format bytes as human-readable string
    var formattedBytes: String {
        ByteCountFormatter.string(fromByteCount: self, countStyle: .binary)
    }

    /// Format as MB with one decimal place
    var formattedMegabytes: String {
        let megabytes: Double = Double(self) / (1_024 * 1_024)
        return String(format: "%.1f MB", megabytes)
    }

    /// Format as GB with two decimal places
    var formattedGigabytes: String {
        let gigabytes: Double = Double(self) / (1_024 * 1_024 * 1_024)
        return String(format: "%.2f GB", gigabytes)
    }
}

/// Date formatting utilities
extension Date {
    /// Format as relative time (e.g., "2 hours ago")
    var relativeTime: String {
        let formatter: RelativeDateTimeFormatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter.localizedString(for: self, relativeTo: Date())
    }

    /// Format as short date and time
    var shortDateTime: String {
        let formatter: DateFormatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter.string(from: self)
    }
}

/// String extensions for file operations
extension String {
    /// Convert repository ID to safe directory name
    var safeDirectoryName: String {
        replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: ":", with: "_")
            .replacingOccurrences(of: "\\", with: "_")
    }

    /// Check if string represents a valid file extension
    var isValidFileExtension: Bool {
        !isEmpty && !contains("/") && !contains("\\") && count <= 10
    }
}

/// Array extensions for file operations
extension Array where Element == URL {
    /// Calculate total size of all files in array
    var totalSize: Int64 {
        reduce(0) { total, url in
            total + (url.fileSize ?? 0)
        }
    }

    /// Filter to only regular files
    var regularFiles: [URL] {
        filter(\.isRegularFile)
    }

    /// Filter to only directories
    var directories: [URL] {
        filter(\.isDirectory)
    }

    /// Sort by modification date (newest first)
    func sortedByModificationDate(ascending: Bool = false) -> [URL] {
        sorted { first, second in
            let date1: Date = first.modificationDate ?? Date.distantPast
            let date2: Date = second.modificationDate ?? Date.distantPast
            return ascending ? date1 < date2 : date1 > date2
        }
    }

    /// Sort by file size (largest first)
    func sortedBySize(ascending: Bool = false) -> [URL] {
        sorted { first, second in
            let size1: Int64 = first.fileSize ?? 0
            let size2: Int64 = second.fileSize ?? 0
            return ascending ? size1 < size2 : size1 > size2
        }
    }
}
