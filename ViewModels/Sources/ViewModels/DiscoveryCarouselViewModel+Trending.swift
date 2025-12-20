import Abstractions
import Foundation

extension DiscoveryCarouselViewModel {
    /// Fetch trending models compatible with MLX or GGUF.
    public func trendingModels(limit: Int = 20) async throws -> [DiscoveredModel] {
        logger.debug("Fetching trending models")
        let page: ModelPage = try await communityExplorer.searchPaginated(
            query: nil,
            author: nil,
            tags: [],
            cursor: nil,
            sort: .trending,
            direction: .descending,
            limit: limit
        )
        return await filterSupportedLanguageModels(page.models)
    }

    /// Fetch recently updated models compatible with MLX or GGUF.
    public func latestModels(limit: Int = 20) async throws -> [DiscoveredModel] {
        logger.debug("Fetching latest models")
        let page: ModelPage = try await communityExplorer.searchPaginated(
            query: nil,
            author: nil,
            tags: [],
            cursor: nil,
            sort: .lastModified,
            direction: .descending,
            limit: limit
        )
        return await filterSupportedLanguageModels(page.models)
    }

    /// Pick the best model that fits the current device.
    public func bestModelForDevice() async -> DiscoveredModel? {
        logger.debug("Selecting best model for current device")
        let compatibleModels: [DiscoveredModel] = await recommendedLanguageModels()
        return await selectBestModel(from: compatibleModels)
    }

    private func filterSupportedLanguageModels(_ models: [DiscoveredModel]) async -> [DiscoveredModel] {
        var filtered: [DiscoveredModel] = []
        filtered.reserveCapacity(models.count)

        for model in models {
            let hasSupportedBackend: Bool = await MainActor.run {
                model.detectedBackends.contains(.mlx) || model.detectedBackends.contains(.gguf)
            }

            guard hasSupportedBackend else {
                continue
            }

            let inferred: SendableModel.ModelType? = await MainActor.run {
                model.inferredModelType
            }

            if let inferred {
                switch inferred {
                case .diffusion, .diffusionXL:
                    continue

                case .language, .deepLanguage, .flexibleThinker, .visualLanguage:
                    filtered.append(model)
                }
            } else {
                filtered.append(model)
            }
        }

        return filtered
    }

    private func selectBestModel(from models: [DiscoveredModel]) async -> DiscoveredModel? {
        guard !models.isEmpty else {
            return nil
        }

        var best: DiscoveredModel?
        var bestScore: UInt64 = 0

        for model in models {
            if let requirement = try? await calculateModelMemoryRequirement(model, modelId: model.id) {
                if requirement > bestScore {
                    bestScore = requirement
                    best = model
                }
            }
        }

        if best == nil {
            var bestDownloads: Int = -1
            for model in models {
                let downloads: Int = await MainActor.run { model.downloads }
                if downloads > bestDownloads {
                    bestDownloads = downloads
                    best = model
                }
            }
        }

        return best
    }
}
