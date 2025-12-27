import Foundation

public protocol PluginSigningKeyBundleLoading: Sendable {
    func loadBundle() async throws -> PluginSigningKeyBundle
}
