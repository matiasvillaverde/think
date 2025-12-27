import Foundation

/// Protocol for managing plugin approvals in the UI.
public protocol PluginApprovalViewModeling: Actor {
    /// Current plugin entries with trust decisions.
    var plugins: [PluginCatalogEntry] { get async }

    /// Whether the view model is loading data.
    var isLoading: Bool { get async }

    /// Error message (if any).
    var errorMessage: String? { get async }

    /// Loads plugin manifests and evaluates trust decisions.
    func loadPlugins() async

    /// Approves a plugin by id.
    func approve(pluginId: String) async

    /// Denies a plugin by id.
    func deny(pluginId: String) async
}
