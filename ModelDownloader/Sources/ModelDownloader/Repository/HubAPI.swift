import Foundation
#if canImport(Darwin)
import Darwin
#else
import Glibc
#endif

/// API client for interacting with HuggingFace Hub
internal actor HubAPI {
    internal let endpoint: String
    internal let fileManager: HFFileManagerProtocol
    internal let httpClient: HTTPClientProtocol
    internal let tokenManager: HFTokenManager
    internal let logger: ModelDownloaderLogger

    /// Initialize HubAPI with dependencies
    internal init(
        endpoint: String = "https://huggingface.co",
        fileManager: HFFileManagerProtocol = DefaultHFFileManager(),
        httpClient: HTTPClientProtocol = DefaultHTTPClient(),
        tokenManager: HFTokenManager? = nil
    ) {
        self.endpoint = endpoint
        self.fileManager = fileManager
        self.httpClient = httpClient
        self.tokenManager = tokenManager ?? HFTokenManager(
            fileManager: fileManager,
            httpClient: httpClient
        )
        self.logger = ModelDownloaderLogger(
            subsystem: "com.think.modeldownloader",
            category: "HubAPI"
        )
    }

    /// Internal HTTP GET method for use by other components
    internal func httpGet(url: URL, headers: [String: String]) async throws -> HTTPClientResponse {
        try await httpClient.get(url: url, headers: headers)
    }

    /// List files in a repository
    /// - Parameters:
    ///   - repo: Repository to list files from
    ///   - revision: Git revision (branch, tag, or commit)
    ///   - includePattern: Optional glob pattern to include files
    ///   - excludePattern: Optional glob pattern to exclude files
    /// - Returns: Array of FileInfo for matching files
    internal func listFiles(
        repo: Repository,
        revision: String = "main",
        includePattern: String? = nil,
        excludePattern: String? = nil
    ) async throws -> [FileInfo] {
        let url: URL = repo.filesAPIURL(revision: revision, recursive: true)

        await logger.info("Listing repository files", metadata: [
            "repo": repo.name,
            "revision": revision,
            "includePattern": includePattern ?? "none",
            "excludePattern": excludePattern ?? "none"
        ])

        // Build headers with optional authentication
        var headers: [String: String] = [:]
        if let token = await tokenManager.getToken() {
            headers["Authorization"] = "Bearer \(token)"
            await logger.debug("Using authentication token for API request")
        } else {
            await logger.debug("No authentication token available")
        }

        await logger.logAPIRequest(method: "GET", url: url, headers: headers)
        let startTime: Date = Date()
        let response: HTTPClientResponse = try await httpClient.get(url: url, headers: headers)
        let duration: TimeInterval = Date().timeIntervalSince(startTime)
        await logger.logAPIResponse(url: url, statusCode: response.statusCode, duration: duration)

        guard response.statusCode == 200 else {
            if response.statusCode == 401 {
                await logger.error("Authentication required for repository", metadata: ["repo": repo.name])
                throw HuggingFaceError.authenticationRequired
            }
            if response.statusCode == 404 {
                await logger.error("Repository not found", metadata: ["repo": repo.name])
                throw HuggingFaceError.repositoryNotFound
            }
            await logger.error("HTTP error listing files", metadata: [
                "repo": repo.name,
                "statusCode": response.statusCode
            ])
            throw HuggingFaceError.httpError(statusCode: response.statusCode)
        }

        // Parse JSON response
        guard let jsonArray = try JSONSerialization.jsonObject(
            with: response.data
        ) as? [[String: Any]] else {
            await logger.error("Invalid JSON response from API", metadata: ["repo": repo.name])
            throw HuggingFaceError.invalidResponse
        }

        // Convert to FileInfo objects
        var files: [FileInfo] = []
        for json in jsonArray {
            // Skip non-file entries (like directories)
            guard let type = json["type"] as? String, type == "file" else {
                continue
            }

            if let fileInfo = FileInfo.from(json: json) {
                files.append(fileInfo)
            }
        }

        await logger.debug("Parsed repository files", metadata: [
            "repo": repo.name,
            "totalFiles": files.count
        ])

        // Apply filters
        let filteredFiles: [FileInfo] = filterFiles(
            files,
            includePattern: includePattern,
            excludePattern: excludePattern
        )

        await logger.info("Listed repository files", metadata: [
            "repo": repo.name,
            "totalFiles": files.count,
            "filteredFiles": filteredFiles.count
        ])

        return filteredFiles
    }

    /// Download file metadata (headers only)
    /// - Parameters:
    ///   - repo: Repository containing the file
    ///   - path: File path within repository
    ///   - revision: Git revision
    /// - Returns: File metadata including size and etag
    internal func fileMetadata(
        repo: Repository,
        path: String,
        revision: String = "main"
    ) async throws -> FileMetadata {
        let url: URL = repo.downloadURL(path: path, revision: revision)

        await logger.debug("Fetching file metadata", metadata: [
            "repo": repo.name,
            "path": path,
            "revision": revision
        ])

        var headers: [String: String] = [:]
        if let token = await tokenManager.getToken() {
            headers["Authorization"] = "Bearer \(token)"
        }

        await logger.logAPIRequest(method: "HEAD", url: url, headers: headers)
        let startTime: Date = Date()
        let response: HTTPClientResponse = try await httpClient.head(url: url, headers: headers)
        let duration: TimeInterval = Date().timeIntervalSince(startTime)
        await logger.logAPIResponse(url: url, statusCode: response.statusCode, duration: duration)

        guard response.statusCode == 200 else {
            if response.statusCode == 401 {
                await logger.error("Authentication required for file metadata", metadata: ["path": path])
                throw HuggingFaceError.authenticationRequired
            }
            if response.statusCode == 404 {
                await logger.error("File not found", metadata: ["path": path])
                throw HuggingFaceError.fileNotFound
            }
            await logger.error("HTTP error fetching file metadata", metadata: [
                "path": path,
                "statusCode": response.statusCode
            ])
            throw HuggingFaceError.httpError(statusCode: response.statusCode)
        }

        // Extract metadata from headers
        let contentLength: Int64 = response.headers["Content-Length"]
            .flatMap { Int64($0) } ?? 0
        let etag: String? = response.headers["ETag"]?.trimmingCharacters(
            in: CharacterSet(charactersIn: "\"")
        )
        let contentType: String? = response.headers["Content-Type"]

        await logger.debug("Retrieved file metadata", metadata: [
            "path": path,
            "size": contentLength,
            "etag": etag ?? "none",
            "contentType": contentType ?? "unknown"
        ])

        return FileMetadata(
            filename: path,
            size: contentLength,
            etag: etag
        )
    }

    /// Get snapshot download information for a repository
    /// - Parameters:
    ///   - repo: Repository to download
    ///   - revision: Git revision
    ///   - includePattern: Optional pattern to include files
    ///   - excludePattern: Optional pattern to exclude files
    ///   - cacheDir: Local cache directory
    /// - Returns: Snapshot download information
    internal func snapshotDownload(
        repo: Repository,
        revision: String = "main",
        includePattern: [String]? = nil,
        excludePattern: [String]? = nil,
        cacheDir: URL? = nil
    ) async throws -> SnapshotDownloadInfo {
        await logger.info("Preparing snapshot download", metadata: [
            "repo": repo.name,
            "revision": revision,
            "includePatterns": includePattern?.count ?? 0,
            "excludePatterns": excludePattern?.count ?? 0
        ])

        // List all files in repository
        let allFiles: [FileInfo] = try await listFiles(
            repo: repo,
            revision: revision,
            includePattern: nil,
            excludePattern: nil
        )

        // Apply multiple patterns if provided
        var filteredFiles: [FileInfo] = allFiles
        if let patterns = includePattern {
            let initialCount: Int = filteredFiles.count
            filteredFiles = filteredFiles.filter { file in
                patterns.contains { pattern in
                    fnmatch(pattern, file.path, 0) == 0
                }
            }
            await logger.debug("Applied include patterns", metadata: [
                "patterns": patterns.joined(separator: ", "),
                "filesBeforeFilter": initialCount,
                "filesAfterFilter": filteredFiles.count
            ])
        }

        if let patterns = excludePattern {
            let initialCount: Int = filteredFiles.count
            filteredFiles = filteredFiles.filter { file in
                !patterns.contains { pattern in
                    fnmatch(pattern, file.path, 0) == 0
                }
            }
            await logger.debug("Applied exclude patterns", metadata: [
                "patterns": patterns.joined(separator: ", "),
                "filesBeforeFilter": initialCount,
                "filesAfterFilter": filteredFiles.count
            ])
        }

        // Get cache directory
        let cacheDirectory: URL = cacheDir ?? getDefaultCacheDir(repo: repo)
        await logger.debug("Using cache directory", metadata: [
            "cacheDir": cacheDirectory.path
        ])

        // Build download info
        var filesToDownload: [FileDownloadInfo] = []
        var cachedFiles: [URL] = []

        for file in filteredFiles {
            let localPath: URL = cacheDirectory.appendingPathComponent(file.path)

            // Check if file exists and matches
            if fileManager.fileExists(atPath: localPath.path) {
                // For now, assume cached files are valid
                // In a full implementation, we'd check ETags
                cachedFiles.append(localPath)
            } else {
                let downloadURL: URL = repo.downloadURL(
                    path: file.path,
                    revision: revision
                )
                filesToDownload.append(
                    FileDownloadInfo(
                        url: downloadURL,
                        localPath: localPath,
                        size: file.size,
                        path: file.path
                    )
                )
            }
        }

        await logger.info("Snapshot download prepared", metadata: [
            "repo": repo.name,
            "totalFiles": filteredFiles.count,
            "filesToDownload": filesToDownload.count,
            "cachedFiles": cachedFiles.count,
            "totalSizeToDownload": filesToDownload.reduce(0) { $0 + $1.size }
        ])

        return SnapshotDownloadInfo(
            repository: repo,
            revision: revision,
            cacheDirectory: cacheDirectory,
            filesToDownload: filesToDownload,
            cachedFiles: cachedFiles
        )
    }

    // MARK: - Private Helpers

    private func filterFiles(
        _ files: [FileInfo],
        includePattern: String?,
        excludePattern: String?
    ) -> [FileInfo] {
        var result: [FileInfo] = files

        if let pattern = includePattern {
            result = result.filter { file in
                fnmatch(pattern, file.path, 0) == 0
            }
        }

        if let pattern = excludePattern {
            result = result.filter { file in
                fnmatch(pattern, file.path, 0) != 0
            }
        }

        return result
    }

    private func getDefaultCacheDir(repo: Repository) -> URL {
        let home: String = fileManager.expandTildeInPath("~")
        return URL(fileURLWithPath: home)
            .appendingPathComponent(".cache")
            .appendingPathComponent("huggingface")
            .appendingPathComponent("hub")
            .appendingPathComponent("\(repo.type.rawValue)--\(repo.id.replacingOccurrences(of: "/", with: "--"))")
    }
}

/// Information about files to download for a snapshot
internal struct SnapshotDownloadInfo: Sendable {
    internal let repository: Repository
    internal let revision: String
    internal let cacheDirectory: URL
    internal let filesToDownload: [FileDownloadInfo]
    internal let cachedFiles: [URL]

    internal var totalBytesToDownload: Int64 {
        filesToDownload.reduce(0) { $0 + $1.size }
    }
}

/// Information about a single file to download
internal struct FileDownloadInfo: Sendable {
    internal let url: URL
    internal let localPath: URL
    internal let size: Int64
    internal let path: String
}
