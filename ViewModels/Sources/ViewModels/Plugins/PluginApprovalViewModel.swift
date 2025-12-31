import Abstractions
import Foundation
import OSLog

/// View model for managing plugin approval decisions.
public final actor PluginApprovalViewModel: PluginApprovalViewModeling {
    private let logger: Logger = Logger(
        subsystem: "ViewModels",
        category: String(describing: PluginApprovalViewModel.self)
    )

    private let manifestLoader: PluginManifestLoading
    private let evaluator: PluginTrustEvaluating

    private var internalPlugins: [PluginCatalogEntry] = []
    private var internalIsLoading: Bool = false
    private var internalErrorMessage: String?

    public var plugins: [PluginCatalogEntry] { internalPlugins }
    public var isLoading: Bool { internalIsLoading }
    public var errorMessage: String? { internalErrorMessage }

    public init(
        manifestLoader: PluginManifestLoading,
        evaluator: PluginTrustEvaluating
    ) {
        self.manifestLoader = manifestLoader
        self.evaluator = evaluator
    }

    public func loadPlugins() async {
        internalIsLoading = true
        internalErrorMessage = nil
        defer { internalIsLoading = false }

        do {
            let manifests: [PluginManifest] = try await manifestLoader.loadManifests()
            var entries: [PluginCatalogEntry] = []
            for manifest in manifests {
                let decision: PluginTrustDecision = try await evaluator.evaluate(manifest: manifest)
                entries.append(PluginCatalogEntry(manifest: manifest, decision: decision))
            }
            internalPlugins = entries.sorted { first, second in
                first.manifest.name.localizedCaseInsensitiveCompare(second.manifest.name) == .orderedAscending
            }
        } catch {
            logger.error("Failed to load plugins: \(error.localizedDescription)")
            internalPlugins = []
            internalErrorMessage = String(
                localized: "Failed to load plugins.",
                bundle: .module
            )
        }
    }

    public func approve(pluginId: String) async {
        guard let entry: PluginCatalogEntry = internalPlugins.first(where: { $0.id == pluginId }) else {
            return
        }

        do {
            try await evaluator.allow(
                pluginId: entry.manifest.id,
                checksum: entry.manifest.checksum
            )
            await loadPlugins()
        } catch {
            logger.error("Failed to approve plugin: \(error.localizedDescription)")
            internalErrorMessage = String(
                localized: "Failed to approve plugin.",
                bundle: .module
            )
        }
    }

    public func deny(pluginId: String) async {
        guard internalPlugins.contains(where: { $0.id == pluginId }) else {
            return
        }

        do {
            try await evaluator.revoke(pluginId: pluginId)
            await loadPlugins()
        } catch {
            logger.error("Failed to deny plugin: \(error.localizedDescription)")
            internalErrorMessage = String(
                localized: "Failed to deny plugin.",
                bundle: .module
            )
        }
    }
}
