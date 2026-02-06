import Foundation
import OSLog

internal enum DatabaseStoreLocator {
    static let defaultStoreName: String = "default.store"

    static func defaultStoreURL(storeName: String = defaultStoreName) -> URL? {
        guard let baseURL = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first else {
            return nil
        }
        return baseURL.appendingPathComponent(storeName)
    }

    static func ensureDirectoryExists(for storeURL: URL) throws {
        let directory = storeURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )
    }
}

internal enum DatabaseStoreResetPolicy {
    // Bump this when a backward-incompatible SwiftData change requires a reset.
    static let currentSchemaVersion: Int = 3
    private static let versionFileExtension: String = "version"

    static func prepareStoreIfNeeded(storeURL: URL, logger: Logger = .database) {
        do {
            try DatabaseStoreLocator.ensureDirectoryExists(for: storeURL)
        } catch {
            logger.warning("Failed to ensure store directory exists: \(error.localizedDescription, privacy: .public)")
            return
        }

        let versionURL = storeURL.appendingPathExtension(versionFileExtension)
        let existingVersion: Int = readVersion(from: versionURL) ?? 0

        if existingVersion < currentSchemaVersion {
            logger.notice(
                "Resetting SwiftData store (schema \(existingVersion) -> \(currentSchemaVersion)) at \(storeURL.path, privacy: .public)"
            )
            removeStoreArtifacts(storeURL: storeURL, logger: logger)
        }

        writeVersion(currentSchemaVersion, to: versionURL, logger: logger)
    }

    private static func readVersion(from url: URL) -> Int? {
        guard let contents = try? String(contentsOf: url, encoding: .utf8) else {
            return nil
        }
        return Int(contents.trimmingCharacters(in: .whitespacesAndNewlines))
    }

    private static func writeVersion(_ version: Int, to url: URL, logger: Logger) {
        do {
            try String(version).write(to: url, atomically: true, encoding: .utf8)
        } catch {
            logger.warning("Failed to write store version file: \(error.localizedDescription, privacy: .public)")
        }
    }

    private static func removeStoreArtifacts(storeURL: URL, logger: Logger) {
        let fileManager = FileManager.default
        let baseURL = storeURL.deletingPathExtension()
        let candidateURLs: [URL] = [
            storeURL,
            baseURL.appendingPathExtension("sqlite"),
            baseURL.appendingPathExtension("sqlite-wal"),
            baseURL.appendingPathExtension("sqlite-shm")
        ]

        for url in candidateURLs where fileManager.fileExists(atPath: url.path) {
            do {
                try fileManager.removeItem(at: url)
            } catch {
                logger.warning("Failed to remove store artifact at \(url.path, privacy: .public)")
                logger.warning(
                    "Store artifact removal error: \(error.localizedDescription, privacy: .public)"
                )
            }
        }
    }
}
