import Foundation

enum AppStoreLocator {
    static let defaultBundleId: String = "com.example.think"
    private static let defaultStoreName: String = "default"

    private static func normalizeStoreBaseName(_ raw: String) -> String {
        // Users often pass "foo" or "foo.store". SwiftData appends ".store" to the *name*.
        // Keep the name stable and avoid accidental "foo.store.store".
        let last = URL(fileURLWithPath: raw).lastPathComponent
        return last.hasSuffix(".store") ? String(last.dropLast(".store".count)) : last
    }

    static func sharedStoreURL(bundleId: String, overridePath: String?) -> URL {
        guard let appSupport = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)
            .first
        else {
            // Fall back to home directory if Application Support cannot be resolved.
            return FileManager.default.homeDirectoryForCurrentUser
                .appendingPathComponent(defaultStoreName)
        }

        if let overridePath {
            let overrideName = normalizeStoreBaseName(overridePath)
            return appSupport.appendingPathComponent(overrideName)
        }

        return appSupport.appendingPathComponent(defaultStoreName)
    }

    static func ensureDirectoryExists(for storeURL: URL) throws {
        let directory = storeURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }
}
