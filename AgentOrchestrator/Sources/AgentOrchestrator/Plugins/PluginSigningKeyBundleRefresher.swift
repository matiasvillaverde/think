import Abstractions
import Foundation
import OSLog

/// Periodically refreshes plugin signing keys from a bundled source.
@preconcurrency
public final actor PluginSigningKeyBundleRefresher {
    private static let logger: Logger = Logger(
        subsystem: "AgentOrchestrator",
        category: "PluginSigningKeyBundleRefresher"
    )

    private let loader: PluginSigningKeyBundleLoading
    private let updater: PluginSigningKeyBundleUpdating
    private let interval: Duration
    private let sleep: @Sendable (Duration) async -> Void
    private let maxIterations: Int?
    private var task: Task<Void, Never>?

    /// Creates a refresher that loads and applies key bundles on a schedule.
    @preconcurrency
    public init(
        loader: PluginSigningKeyBundleLoading,
        updater: PluginSigningKeyBundleUpdating,
        interval: Duration,
        sleep: @escaping @Sendable (Duration) async -> Void = { duration in
            try? await Task.sleep(for: duration)
        },
        maxIterations: Int? = nil
    ) {
        self.loader = loader
        self.updater = updater
        self.interval = interval
        self.sleep = sleep
        self.maxIterations = maxIterations
    }

    /// Starts the refresh loop and returns the underlying task.
    @discardableResult
    public func start() -> Task<Void, Never> {
        if let task {
            return task
        }

        let task: Task<Void, Never> = makeTask()
        self.task = task
        return task
    }

    /// Stops the refresh loop if running.
    public func stop() {
        task?.cancel()
        task = nil
    }

    private func makeTask() -> Task<Void, Never> {
        Task {
            await runLoop()
        }
    }

    private func runLoop() async {
        var iterations: Int = 0
        while !Task.isCancelled {
            await refreshOnce()
            iterations += 1
            if let maxIterations, iterations >= maxIterations {
                break
            }
            await sleep(interval)
        }
    }

    private func refreshOnce() async {
        do {
            let bundle: PluginSigningKeyBundle = try await loader.loadBundle()
            try await updater.apply(bundle: bundle)
        } catch {
            Self.logger.warning(
                "Failed to refresh plugin signing keys: \(error.localizedDescription)"
            )
        }
    }
}
