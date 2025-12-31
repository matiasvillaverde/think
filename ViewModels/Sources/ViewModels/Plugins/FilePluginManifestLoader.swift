import Abstractions
import Foundation
import OSLog

/// Loads plugin manifests from a directory on disk.
public struct FilePluginManifestLoader: PluginManifestLoading, @unchecked Sendable {
    private static let logger: Logger = Logger(
        subsystem: "ViewModels",
        category: "FilePluginManifestLoader"
    )

    private let pluginDirectory: URL
    private let fileManager: FileManager
    private let decoder: JSONDecoder
    private let manifestFileNames: [String]

    public init(
        pluginDirectory: URL,
        fileManager: FileManager = .default,
        manifestFileNames: [String] = ["plugin.json", "manifest.json"]
    ) {
        self.pluginDirectory = pluginDirectory
        self.fileManager = fileManager
        self.decoder = JSONDecoder()
        self.manifestFileNames = manifestFileNames
    }

    public func loadManifests() async throws -> [PluginManifest] {
        try Task.checkCancellation()
        await Task.yield()

        guard fileManager.fileExists(atPath: pluginDirectory.path) else {
            return []
        }

        let entries: [URL] = try fileManager.contentsOfDirectory(
            at: pluginDirectory,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        )

        var manifests: [PluginManifest] = []

        for entry in entries {
            if let manifest: PluginManifest = try loadManifest(from: entry) {
                manifests.append(manifest)
            }
        }

        return manifests
    }

    private func loadManifest(from entry: URL) throws -> PluginManifest? {
        let values: URLResourceValues = try entry.resourceValues(forKeys: [.isDirectoryKey])
        if values.isDirectory == true {
            for name in manifestFileNames {
                let candidate: URL = entry.appendingPathComponent(name)
                if fileManager.fileExists(atPath: candidate.path) {
                    return decodeManifest(from: candidate)
                }
            }
            return nil
        }

        guard manifestFileNames.contains(entry.lastPathComponent) else {
            return nil
        }

        return decodeManifest(from: entry)
    }

    private func decodeManifest(from url: URL) -> PluginManifest? {
        do {
            let data: Data = try Data(contentsOf: url)
            return try decoder.decode(PluginManifest.self, from: data)
        } catch {
            Self.logger.warning("Failed to decode plugin manifest at \(url.path)")
            return nil
        }
    }
}
