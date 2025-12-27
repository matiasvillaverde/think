import Foundation

public protocol PluginTrustStoring: Sendable {
    func load() async throws -> PluginTrustSnapshot
    func save(_ snapshot: PluginTrustSnapshot) async throws
}

public protocol PluginTrustEvaluating: Sendable {
    func evaluate(manifest: PluginManifest) async throws -> PluginTrustDecision
    func allow(pluginId: String, checksum: String?) async throws
    func revoke(pluginId: String) async throws
}
