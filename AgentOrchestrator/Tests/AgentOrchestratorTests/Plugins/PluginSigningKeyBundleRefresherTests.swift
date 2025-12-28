import Abstractions
import Foundation
import Testing

@testable import AgentOrchestrator

@Suite("PluginSigningKeyBundleRefresher Tests")
internal struct PluginSigningKeyBundleRefresherTests {
    @Test("Refresher loads and applies bundle")
    internal func refresherLoadsAndAppliesBundle() async {
        let bundle: PluginSigningKeyBundle = PluginSigningKeyBundle(
            issuedAt: Date(),
            keys: []
        )
        let loader: MockBundleLoader = MockBundleLoader(bundle: bundle)
        let updater: MockBundleUpdater = MockBundleUpdater()
        let refresher: PluginSigningKeyBundleRefresher = PluginSigningKeyBundleRefresher(
            loader: loader,
            updater: updater,
            interval: .seconds(60),
            sleep: { _ in await Task.yield() },
            maxIterations: 1
        )

        let task: Task<Void, Never> = await refresher.start()
        await task.value

        let loadCount: Int = await loader.loadCount()
        let applyCount: Int = await updater.applyCount()
        #expect(loadCount == 1)
        #expect(applyCount == 1)
    }
}
