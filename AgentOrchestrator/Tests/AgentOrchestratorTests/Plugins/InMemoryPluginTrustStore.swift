import Abstractions
import Foundation

internal actor InMemoryPluginTrustStore: PluginTrustStoring {
    private var snapshot: PluginTrustSnapshot

    internal init(snapshot: PluginTrustSnapshot = PluginTrustSnapshot()) {
        self.snapshot = snapshot
    }

    internal func load() async throws -> PluginTrustSnapshot {
        try Task.checkCancellation()
        await Task.yield()
        return snapshot
    }

    internal func save(_ snapshot: PluginTrustSnapshot) async throws {
        try Task.checkCancellation()
        await Task.yield()
        self.snapshot = snapshot
    }
}
