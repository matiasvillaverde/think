import Embeddings
import Foundation

internal protocol RagModelCaching: Actor {
    func model(for config: ModelConfiguration) async throws -> Bert.ModelBundle
    func reset()
    func currentLoadCount() -> Int
}

internal protocol ModelBundleLoading: Sendable {
    func loadModelBundle(from config: ModelConfiguration) async throws -> Bert.ModelBundle
}

internal struct DefaultModelBundleLoader: ModelBundleLoading {
    func loadModelBundle(from config: ModelConfiguration) async throws -> Bert.ModelBundle {
        if let localURL = config.localURL {
            return try await Bert.loadModelBundle(from: localURL)
        }

        return try await Bert.loadModelBundle(
            from: config.hubRepoId,
            useBackgroundSession: config.useBackgroundSession
        )
    }
}

internal struct ModelConfigurationKey: Hashable, Sendable {
    let hubRepoId: String
    let localPath: String?
    let useBackgroundSession: Bool
}

internal actor RagModelCache: RagModelCaching {
    static let shared: RagModelCache = RagModelCache(loader: DefaultModelBundleLoader())

    private let loader: any ModelBundleLoading
    private var cache: [ModelConfigurationKey: Bert.ModelBundle] = [:]
    private var loadingTasks: [ModelConfigurationKey: Task<Bert.ModelBundle, Error>] = [:]
    private var loadCount: Int = 0

    init(loader: any ModelBundleLoading) {
        self.loader = loader
    }

    func model(for config: ModelConfiguration) async throws -> Bert.ModelBundle {
        let key: ModelConfigurationKey = config.cacheKey

        if let cached = cache[key] {
            return cached
        }

        if let task = loadingTasks[key] {
            return try await task.value
        }

        let task: Task<Bert.ModelBundle, Error> = Task { [loader] in
            try await loader.loadModelBundle(from: config)
        }
        loadingTasks[key] = task
        loadCount += 1

        do {
            let model: Bert.ModelBundle = try await task.value
            cache[key] = model
            loadingTasks[key] = nil
            return model
        } catch {
            loadingTasks[key] = nil
            throw error
        }
    }

    func reset() {
        for task in loadingTasks.values {
            task.cancel()
        }
        loadingTasks.removeAll()
        cache.removeAll()
        loadCount = 0
    }

    func currentLoadCount() -> Int {
        loadCount
    }
}

extension ModelConfiguration {
    var cacheKey: ModelConfigurationKey {
        ModelConfigurationKey(
            hubRepoId: hubRepoId,
            localPath: localURL?.standardizedFileURL.path,
            useBackgroundSession: useBackgroundSession
        )
    }
}
