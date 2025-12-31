import Abstractions
import Foundation
import Testing
@testable import ViewModels

@Suite("Plugin Approval ViewModel Tests")
internal struct PluginApprovalViewModelTests {
    private actor MockManifestLoader: PluginManifestLoading {
        private(set) var callCount: Int = 0
        private let manifests: [PluginManifest]
        private let error: Error?

        init(manifests: [PluginManifest], error: Error? = nil) {
            self.manifests = manifests
            self.error = error
        }

        func loadManifests() async throws -> [PluginManifest] {
            try Task.checkCancellation()
            await Task.yield()
            callCount += 1
            if let error {
                throw error
            }
            return manifests
        }

        func calls() -> Int { callCount }
    }

    private actor MockTrustEvaluator: PluginTrustEvaluating {
        private let decisions: [String: PluginTrustDecision]
        private var allowCalls: [(String, String?)] = []
        private var revokeCalls: [String] = []

        init(decisions: [String: PluginTrustDecision]) {
            self.decisions = decisions
        }

        func evaluate(manifest: PluginManifest) async throws -> PluginTrustDecision {
            try Task.checkCancellation()
            await Task.yield()
            return decisions[manifest.id]
            ?? PluginTrustDecision(level: .requiresUserApproval, reasons: [.unknown])
        }

        func allow(pluginId: String, checksum: String?) async throws {
            try Task.checkCancellation()
            await Task.yield()
            allowCalls.append((pluginId, checksum))
        }

        func revoke(pluginId: String) async throws {
            try Task.checkCancellation()
            await Task.yield()
            revokeCalls.append(pluginId)
        }

        func allowed() async -> [(String, String?)] {
            await Task.yield()
            return allowCalls
        }

        func revoked() async -> [String] {
            await Task.yield()
            return revokeCalls
        }
    }

    private enum MockError: Error {
        case failure
    }

    @Test("Loads plugin entries with trust decisions")
    func loadsPlugins() async {
        let manifestA: PluginManifest = PluginManifest(
            id: "com.example.alpha",
            name: "Alpha",
            version: "1.0.0",
            checksum: "abc123"
        )
        let manifestB: PluginManifest = PluginManifest(
            id: "com.example.beta",
            name: "Beta",
            version: "2.0.0",
            checksum: "def456"
        )

        let loader: MockManifestLoader = MockManifestLoader(manifests: [manifestA, manifestB])
        let evaluator: MockTrustEvaluator = MockTrustEvaluator(decisions: [
            manifestA.id: PluginTrustDecision(level: .requiresUserApproval, reasons: [.unknown]),
            manifestB.id: PluginTrustDecision(level: .trusted, reasons: [.signed])
        ])

        let viewModel: PluginApprovalViewModel = PluginApprovalViewModel(
            manifestLoader: loader,
            evaluator: evaluator
        )

        await viewModel.loadPlugins()
        let entries: [PluginCatalogEntry] = await viewModel.plugins

        #expect(entries.count == 2)
        #expect(entries.contains { $0.id == manifestA.id && $0.decision.level == .requiresUserApproval })
        #expect(entries.contains { $0.id == manifestB.id && $0.decision.level == .trusted })
    }

    @Test("Approve records allow and reloads manifests")
    func approveRecordsAllow() async {
        let manifest: PluginManifest = PluginManifest(
            id: "com.example.alpha",
            name: "Alpha",
            version: "1.0.0",
            checksum: "abc123"
        )

        let loader: MockManifestLoader = MockManifestLoader(manifests: [manifest])
        let evaluator: MockTrustEvaluator = MockTrustEvaluator(decisions: [
            manifest.id: PluginTrustDecision(level: .requiresUserApproval, reasons: [.unknown])
        ])

        let viewModel: PluginApprovalViewModel = PluginApprovalViewModel(
            manifestLoader: loader,
            evaluator: evaluator
        )

        await viewModel.loadPlugins()
        await viewModel.approve(pluginId: manifest.id)

        let allowCalls: [(String, String?)] = await evaluator.allowed()
        let loadCalls: Int = await loader.calls()

        #expect(allowCalls.count == 1)
        #expect(allowCalls.first?.0 == manifest.id)
        #expect(allowCalls.first?.1 == manifest.checksum)
        #expect(loadCalls == 2)
    }

    @Test("Deny records revoke and reloads manifests")
    func denyRecordsRevoke() async {
        let manifest: PluginManifest = PluginManifest(
            id: "com.example.alpha",
            name: "Alpha",
            version: "1.0.0",
            checksum: "abc123"
        )

        let loader: MockManifestLoader = MockManifestLoader(manifests: [manifest])
        let evaluator: MockTrustEvaluator = MockTrustEvaluator(decisions: [
            manifest.id: PluginTrustDecision(level: .requiresUserApproval, reasons: [.unknown])
        ])

        let viewModel: PluginApprovalViewModel = PluginApprovalViewModel(
            manifestLoader: loader,
            evaluator: evaluator
        )

        await viewModel.loadPlugins()
        await viewModel.deny(pluginId: manifest.id)

        let revokeCalls: [String] = await evaluator.revoked()
        let loadCalls: Int = await loader.calls()

        #expect(revokeCalls == [manifest.id])
        #expect(loadCalls == 2)
    }

    @Test("Loader errors surface an error message")
    func loaderErrorsSurfaceMessage() async {
        let loader: MockManifestLoader = MockManifestLoader(manifests: [], error: MockError.failure)
        let evaluator: MockTrustEvaluator = MockTrustEvaluator(decisions: [:])

        let viewModel: PluginApprovalViewModel = PluginApprovalViewModel(
            manifestLoader: loader,
            evaluator: evaluator
        )

        await viewModel.loadPlugins()

        let entries: [PluginCatalogEntry] = await viewModel.plugins
        let errorMessage: String? = await viewModel.errorMessage

        #expect(entries.isEmpty)
        #expect(errorMessage != nil)
    }
}
