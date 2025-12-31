import Abstractions
import Foundation
import Testing
@testable import ViewModels

@Suite("File Plugin Manifest Loader Tests")
internal struct FilePluginManifestLoaderTests {
    @Test("Loads manifest files from plugin directories")
    func loadsManifestFromDirectory() async throws {
        let fileManager: FileManager = .default
        let tempDirectory: URL = fileManager.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? fileManager.removeItem(at: tempDirectory) }

        try fileManager.createDirectory(at: tempDirectory, withIntermediateDirectories: true)

        let pluginDirectory: URL = tempDirectory.appendingPathComponent("Alpha", isDirectory: true)
        try fileManager.createDirectory(at: pluginDirectory, withIntermediateDirectories: true)

        let manifest: PluginManifest = PluginManifest(
            id: "com.example.alpha",
            name: "Alpha",
            version: "1.0.0",
            checksum: "abc123"
        )

        let data: Data = try JSONEncoder().encode(manifest)
        let manifestURL: URL = pluginDirectory.appendingPathComponent("manifest.json")
        try data.write(to: manifestURL)

        let loader: FilePluginManifestLoader = FilePluginManifestLoader(pluginDirectory: tempDirectory)
        let manifests: [PluginManifest] = try await loader.loadManifests()

        #expect(manifests.count == 1)
        #expect(manifests.first == manifest)
    }

    @Test("Loads manifest files from root plugin directory")
    func loadsManifestFromRoot() async throws {
        let fileManager: FileManager = .default
        let tempDirectory: URL = fileManager.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? fileManager.removeItem(at: tempDirectory) }

        try fileManager.createDirectory(at: tempDirectory, withIntermediateDirectories: true)

        let manifest: PluginManifest = PluginManifest(
            id: "com.example.beta",
            name: "Beta",
            version: "2.0.0",
            checksum: "def456"
        )

        let data: Data = try JSONEncoder().encode(manifest)
        let manifestURL: URL = tempDirectory.appendingPathComponent("plugin.json")
        try data.write(to: manifestURL)

        let loader: FilePluginManifestLoader = FilePluginManifestLoader(pluginDirectory: tempDirectory)
        let manifests: [PluginManifest] = try await loader.loadManifests()

        #expect(manifests.count == 1)
        #expect(manifests.first == manifest)
    }
}
