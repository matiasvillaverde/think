import Foundation

/// A plugin entry paired with its current trust decision.
public struct PluginCatalogEntry: Sendable, Identifiable, Equatable {
    public let manifest: PluginManifest
    public let decision: PluginTrustDecision

    public var id: String { manifest.id }

    public init(manifest: PluginManifest, decision: PluginTrustDecision) {
        self.manifest = manifest
        self.decision = decision
    }
}
