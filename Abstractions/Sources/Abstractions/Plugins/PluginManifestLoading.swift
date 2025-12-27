import Foundation

/// Loads plugin manifests from a backing store.
public protocol PluginManifestLoading: Sendable {
    func loadManifests() async throws -> [PluginManifest]
}
