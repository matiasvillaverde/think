import Abstractions
import Foundation

internal actor MockBundleLoader: PluginSigningKeyBundleLoading {
    private let bundle: PluginSigningKeyBundle
    private var count: Int = 0

    internal init(bundle: PluginSigningKeyBundle) {
        self.bundle = bundle
    }

    internal func loadBundle() async throws -> PluginSigningKeyBundle {
        try Task.checkCancellation()
        await Task.yield()
        count += 1
        return bundle
    }

    internal func loadCount() -> Int {
        count
    }
}
