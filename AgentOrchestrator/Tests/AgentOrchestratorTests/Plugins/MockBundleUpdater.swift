import Abstractions
import Foundation

internal actor MockBundleUpdater: PluginSigningKeyBundleUpdating {
    private var count: Int = 0

    internal func apply(bundle: PluginSigningKeyBundle) async throws {
        _ = bundle
        try Task.checkCancellation()
        await Task.yield()
        count += 1
    }

    internal func applyCount() -> Int {
        count
    }
}
