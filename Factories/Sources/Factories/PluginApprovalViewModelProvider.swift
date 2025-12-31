import Abstractions
import AgentOrchestrator
import Foundation
import SwiftUI
import UIComponents
import ViewModels

// MARK: - Plugin Approval ViewModel Provider

public struct PluginApprovalViewModelProvider: ViewModifier {
    @State private var keyRefresher: PluginSigningKeyBundleRefresher?
    @State private var keyRefresherTask: Task<Void, Never>?

    private enum Constants {
        static let secondsPerDay: Int = 86_400
    }

    public init() {
        // Initialize provider
    }

    public func body(content: Content) -> some View {
        let fileManager: FileManager = FileManager()
        let pluginDirectory: URL = pluginDirectoryURL(using: fileManager)
        let trustStoreURL: URL = pluginDirectory.appendingPathComponent("trust.json")
        let bundleURL: URL = pluginDirectory.appendingPathComponent("signing-keys.json")

        let trustStore: FilePluginTrustStore = FilePluginTrustStore(fileURL: trustStoreURL)

        let evaluator: PluginTrustEvaluator = PluginTrustEvaluator(store: trustStore)
        let loader: FilePluginManifestLoader = FilePluginManifestLoader(
            pluginDirectory: pluginDirectory,
            fileManager: fileManager
        )

        let viewModel: PluginApprovalViewModel = PluginApprovalViewModel(
            manifestLoader: loader,
            evaluator: evaluator
        )

        return content
            .environment(\.pluginApprovalViewModel, viewModel)
            .task {
                guard fileManager.fileExists(atPath: bundleURL.path) else {
                    return
                }
                if keyRefresher == nil {
                    let bundleLoader: FilePluginSigningKeyBundleLoader =
                        FilePluginSigningKeyBundleLoader(fileURL: bundleURL)
                    let updater: PluginSigningKeyBundleUpdater =
                        PluginSigningKeyBundleUpdater(store: trustStore)
                    keyRefresher = PluginSigningKeyBundleRefresher(
                        loader: bundleLoader,
                        updater: updater,
                        interval: .seconds(Constants.secondsPerDay)
                    )
                }
                if keyRefresherTask == nil, let keyRefresher {
                    keyRefresherTask = await keyRefresher.start()
                }
            }
            .onDisappear {
                if let keyRefresher {
                    Task { await keyRefresher.stop() }
                }
                keyRefresherTask = nil
            }
    }

    private func pluginDirectoryURL(using fileManager: FileManager) -> URL {
        let appSupport: URL = fileManager.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first ?? fileManager.temporaryDirectory

        return appSupport.appendingPathComponent("ThinkAI/Plugins", isDirectory: true)
    }
}

extension View {
    public func withPluginApprovalViewModel() -> some View {
        modifier(PluginApprovalViewModelProvider())
    }
}
