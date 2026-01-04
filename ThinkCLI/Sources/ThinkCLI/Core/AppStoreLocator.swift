import Foundation

enum AppStoreLocator {
    static let defaultBundleId: String = "com.example.think"
    private static let defaultStoreName: String = "default.store"

    static func sharedStoreURL(bundleId: String, overridePath: String?) -> URL {
        let containerRoot = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Containers")
            .appendingPathComponent(bundleId)
            .appendingPathComponent("Data/Library/Application Support")

        if let overridePath {
            let overrideName = URL(fileURLWithPath: overridePath).lastPathComponent
            return containerRoot.appendingPathComponent(overrideName)
        }

        return containerRoot.appendingPathComponent(defaultStoreName)
    }

    static func ensureDirectoryExists(for storeURL: URL) throws {
        let directory = storeURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }
}
