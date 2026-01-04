import Foundation

enum AppStoreLocator {
    static let defaultBundleId: String = "com.example.think"
    private static let defaultStoreName: String = "default.store"

    static func sharedStoreURL(bundleId: String, overridePath: String?) -> URL {
        if let overridePath {
            return URL(fileURLWithPath: overridePath)
        }

        let containerRoot = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Containers")
            .appendingPathComponent(bundleId)
            .appendingPathComponent("Data/Library/Application Support")

        return containerRoot.appendingPathComponent(defaultStoreName)
    }

    static func ensureDirectoryExists(for storeURL: URL) throws {
        let directory = storeURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }
}
