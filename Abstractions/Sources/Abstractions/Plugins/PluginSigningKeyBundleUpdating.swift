import Foundation

public protocol PluginSigningKeyBundleUpdating: Sendable {
    func apply(bundle: PluginSigningKeyBundle) async throws
}
