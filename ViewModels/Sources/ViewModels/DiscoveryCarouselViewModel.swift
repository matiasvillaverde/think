import Abstractions
import DataAssets
import Foundation
import OSLog

/// Actor-based ViewModel for discovering and recommending AI models
public actor DiscoveryCarouselViewModel: DiscoveryCarouselViewModeling {
    // MARK: - Constants

    /// Default query limit for community exploration
    private static let defaultQueryLimit: Int = 10

    /// Multiplier to convert parameter count from billions to full count
    private static let billionParameterMultiplier: Double = 1_000_000_000

    internal let communityExplorer: CommunityModelsExplorerProtocol
    private let deviceChecker: DeviceCompatibilityProtocol
    private let vramCalculator: VRAMCalculatorProtocol
    internal let logger: Logger = Logger(subsystem: "ViewModels", category: "DiscoveryCarousel")

    /// Configurable memory overhead percentage (default 25%)
    /// This accounts for inference runtime overhead including:
    /// - KV cache for context
    /// - Attention computation buffers
    /// - Activation memory
    /// - Framework overhead
    private let memoryOverheadPercentage: Double

    // Cached device memory info to avoid repeated calls
    private var cachedDeviceMemory: DeviceMemoryInfo?

    public init(
        communityExplorer: CommunityModelsExplorerProtocol,
        deviceChecker: DeviceCompatibilityProtocol,
        vramCalculator: VRAMCalculatorProtocol,
        memoryOverheadPercentage: Double = 0.25
    ) {
        self.communityExplorer = communityExplorer
        self.deviceChecker = deviceChecker
        self.vramCalculator = vramCalculator
        self.memoryOverheadPercentage = memoryOverheadPercentage

        logger.info("DiscoveryCarouselViewModel initialized with \(memoryOverheadPercentage * 100)% memory overhead")
    }

    public func recommendedLanguageModels() async throws -> [DiscoveredModel] {
        logger.debug("Fetching recommended language models")

        let compatibleModels: [DiscoveredModel] = try await discoverCompatibleModels(modelType: .language)
        logger.info("Found \(compatibleModels.count) compatible recommended language models")
        return compatibleModels
    }

    public func recommendedAllModels() async throws -> [DiscoveredModel] {
        logger.debug("Fetching all recommended models")

        let compatibleModels: [DiscoveredModel] = try await discoverCompatibleModels(modelType: .all)
        logger.info("Found \(compatibleModels.count) compatible recommended models (all types)")
        return compatibleModels
    }

    private enum ModelType {
        case language
        case all
    }

    private func discoverCompatibleModels(modelType: ModelType) async throws -> [DiscoveredModel] {
        logger.debug("Checking device memory availability")
        let deviceMemory: DeviceMemoryInfo = await deviceChecker.getDeviceMemoryInfo()
        cachedDeviceMemory = deviceMemory
        logger.info("Device memory info retrieved: available=\(deviceMemory.availableMemory) bytes, total=\(deviceMemory.totalMemory) bytes")
        // Get only the models appropriate for this device's memory
        // Use total memory for tier classification to match device capability
        let recommendedModelIds: [String]
        switch modelType {
        case .language:
            recommendedModelIds = RecommendedModels.getLanguageModelsForExactTier(forMemory: deviceMemory.totalMemory)
            logger.info("Found \(recommendedModelIds.count) language models appropriate for device memory tier")

        case .all:
            let languageModels: [String] = RecommendedModels.getLanguageModelsForExactTier(forMemory: deviceMemory.totalMemory)
            let imageModels: [String] = RecommendedModels.getImageModels(forMemory: deviceMemory.totalMemory)
            recommendedModelIds = languageModels + imageModels
            logger.info("""
                Found \(recommendedModelIds.count) total models \
                (\(languageModels.count) language + \(imageModels.count) image) appropriate for device
                """)
        }

        var compatibleModels: [DiscoveredModel] = []
        var modelMemoryRequirements: [String: UInt64] = [:]

        for modelId in recommendedModelIds {
            if let model = try await processModelForRecommendation(modelId) {
                compatibleModels.append(model)

                // Store memory requirement for sorting
                if let memoryReq: UInt64 = try? await calculateModelMemoryRequirement(model, modelId: modelId) {
                    modelMemoryRequirements[modelId] = memoryReq
                }
            }
        }

        // Sort models: prioritize ALL tagged models first, then by memory requirement
        await MainActor.run {
            compatibleModels.sort { model1, model2 in
                // Check if either model has a recommendation type (tag)
                let hasModel1Tag: Bool = model1.recommendationType != nil
                let hasModel2Tag: Bool = model2.recommendationType != nil

                // If one has a tag and the other doesn't, tagged model goes first
                if hasModel1Tag, !hasModel2Tag {
                    return true
                }
                if !hasModel1Tag, hasModel2Tag {
                    return false
                }

                // If both have tags or both don't have tags, sort by memory requirement (highest first)
                let mem1: UInt64 = modelMemoryRequirements[model1.id] ?? 0
                let mem2: UInt64 = modelMemoryRequirements[model2.id] ?? 0
                return mem1 > mem2
            }
        }

        return compatibleModels
    }

    private func processModelForRecommendation(_ modelId: String) async throws -> DiscoveredModel? {
        do {
            let model: DiscoveredModel = try await communityExplorer.discoverModel(modelId)
            let requirements: MemoryRequirements = try await calculateModelRequirements(model, modelId: modelId)

            logger.debug("Memory requirements for \(modelId): \(requirements.formattedTotalMemory)")

            let compatibility: DeviceCompatibility = await deviceChecker.checkCompatibility(for: requirements)

            if case .fullGPUOffload = compatibility {
                logger.info("Model \(modelId) is compatible (full GPU offload): \(requirements.formattedTotalMemory)")
                return model
            }

            logger.debug("Model \(modelId) is not compatible for full GPU offload: \(String(describing: compatibility))")
            return nil
        } catch {
            logger.error("Failed to process model \(modelId): \(error.localizedDescription)")
            return nil
        }
    }

    private func calculateModelMemoryRequirement(_ model: DiscoveredModel, modelId: String) async throws -> UInt64 {
        let requirements: MemoryRequirements = try await MainActor.run {
            try calculateModelRequirements(model, modelId: modelId)
        }
        return requirements.totalMemory
    }

    @MainActor
    private func calculateModelRequirements(_ model: DiscoveredModel, modelId: String) throws -> MemoryRequirements {
        if let parametersFromCard = extractParameterCount(from: model.modelCard) {
            logger.debug("Using parameter count (\(parametersFromCard)) for model \(modelId)")
            let quantization: QuantizationLevel = detectQuantization(from: model) ?? .int4
            return try vramCalculator.calculateMemoryRequirements(
                parameters: parametersFromCard,
                quantization: quantization,
                overheadPercentage: memoryOverheadPercentage
            )
        }

        logger.debug("Using file size estimation for model \(modelId)")
        let fileSize: UInt64 = calculateTotalFileSize(model)
        let quantization: QuantizationLevel = detectQuantization(from: model) ?? .int4
        return vramCalculator.estimateFromFileSize(
            fileSize: fileSize,
            quantization: quantization,
            overheadPercentage: memoryOverheadPercentage
        )
    }

    public func getDefaultCommunitiesFromProtocol() -> [ModelCommunity] {
        logger.debug("Getting default communities from protocol method")
        return communityExplorer.getDefaultCommunities()
    }

    public func latestModelsFromDefaultCommunitiesProgressive() -> AsyncStream<(ModelCommunity, [DiscoveredModel])> {
        logger.debug("Starting progressive loading with enrichment of community models")

        return AsyncStream { continuation in
            Task {
                await self.performProgressiveLoading(continuation: continuation)
            }
        }
    }

    public func latestModelsFromDefaultCommunities() async throws -> [ModelCommunity: [DiscoveredModel]] {
        logger.debug("Fetching latest models from default communities")
        var result: [ModelCommunity: [DiscoveredModel]] = [:]
        // Fetch models from each default community using protocol method
        for community in communityExplorer.getDefaultCommunities() {
            do {
                let models: [DiscoveredModel] = try await communityExplorer.exploreCommunity(
                    community,
                    query: nil,
                    sort: .downloads,
                    direction: .descending,
                    limit: Self.defaultQueryLimit
                )
                result[community] = models
                logger.debug("Fetched \(models.count) models from \(community.id)")
            } catch {
                logger.error("Failed to fetch models from \(community.id): \(error.localizedDescription)")
                // Continue with other communities if one fails
                result[community] = []
            }
        }

        let totalModels: Int = result.values.reduce(0) { $0 + $1.count }
        logger.info("Fetched \(totalModels) total models from \(result.keys.count) communities")
        return result
    }
    // MARK: - Private Methods
    nonisolated private func extractParameterCount(from modelCard: String?) -> UInt64? {
        guard let card = modelCard else {
            return nil
        }
        let patterns: [String] = [
            "(\\d+(?:\\.\\d+)?)\\s*B\\s*parameters?",
            "parameters?:\\s*(\\d+(?:\\.\\d+)?)\\s*[Bb]",
            "model\\s+size:\\s*(\\d+(?:\\.\\d+)?)\\s*[Bb]"
        ]
        for pattern in patterns {
            guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) else { continue }
            let range: NSRange = NSRange(location: 0, length: card.utf16.count)
            if let match = regex.firstMatch(in: card, options: [], range: range),
                match.numberOfRanges > 1,
                let numberRange: Range = Range(match.range(at: 1), in: card),
                let value: Double = Double(card[numberRange]) {
                return UInt64(value * Self.billionParameterMultiplier)
            }
        }
        return nil
    }

    @MainActor
    private func detectQuantization(from model: DiscoveredModel) -> QuantizationLevel? {
        // Check filenames for quantization hints
        for file in model.files {
            if let detected = QuantizationLevel.detectFromFilename(file.filename) {
                return detected
            }
        }

        // Check model ID for quantization hints
        return QuantizationLevel.detectFromFilename(model.id)
    }

    @MainActor
    private func calculateTotalFileSize(_ model: DiscoveredModel) -> UInt64 {
        UInt64(max(0, model.files.reduce(Int64(0)) { $0 + ($1.size ?? 0) }))
    }
}

// MARK: - Progressive Loading Extension
extension DiscoveryCarouselViewModel {
    private func performProgressiveLoading(
        continuation: AsyncStream<(ModelCommunity, [DiscoveredModel])>.Continuation
    ) async {
        // Phase 1: Load basic models quickly for immediate UI display
        let communityBasicModels: [ModelCommunity: [DiscoveredModel]] = await loadBasicModelsForAllCommunities(
            continuation: continuation
        )

        // Phase 2: Enrich models in background and yield updated versions
        await enrichModelsForAllCommunities(communityBasicModels: communityBasicModels, continuation: continuation)

        // End the stream
        continuation.finish()
    }

    private func loadBasicModelsForAllCommunities(
        continuation: AsyncStream<(ModelCommunity, [DiscoveredModel])>.Continuation
    ) async -> [ModelCommunity: [DiscoveredModel]] {
        var communityBasicModels: [ModelCommunity: [DiscoveredModel]] = [:]

        await withTaskGroup(of: (ModelCommunity, [DiscoveredModel]).self) { basicGroup in
            for community in communityExplorer.getDefaultCommunities() {
                basicGroup.addTask {
                    do {
                        let basicModels: [DiscoveredModel] = try await self.communityExplorer.exploreCommunity(
                            community,
                            query: nil,
                            sort: .downloads,
                            direction: .descending,
                            limit: Self.defaultQueryLimit
                        )
                        self.logger.debug("Fetched \(basicModels.count) basic models from \(community.id)")
                        return (community, basicModels)
                    } catch {
                        self.logger.error("Failed to fetch basic models from \(community.id): \(error.localizedDescription)")
                        return (community, [])
                    }
                }
            }

            // Yield basic results immediately for fast UI
            for await (community, basicModels) in basicGroup {
                communityBasicModels[community] = basicModels
                continuation.yield((community, basicModels))
            }
        }

        return communityBasicModels
    }

    private func enrichModelsForAllCommunities(
        communityBasicModels: [ModelCommunity: [DiscoveredModel]],
        continuation: AsyncStream<(ModelCommunity, [DiscoveredModel])>.Continuation
    ) async {
        await withTaskGroup(of: (ModelCommunity, [DiscoveredModel]).self) { enrichGroup in
            for (community, basicModels) in communityBasicModels {
                guard !basicModels.isEmpty else { continue }

                enrichGroup.addTask {
                    self.logger.debug("Starting enrichment for \(basicModels.count) models from \(community.id)")

                    let enrichedModels: [DiscoveredModel] = await self.communityExplorer.enrichModels(basicModels)

                    let (successfulEnrichments, imageStats): (Int, String) = await MainActor.run {
                        let successfulCount: Int = enrichedModels.filter { model in
                            model.modelCard != nil || model.cardData != nil || !model.imageUrls.isEmpty
                        }.count

                        let imageStats: String = enrichedModels
                            .map { model in
                                let imageCount: Int = model.imageUrls.count
                                return "\(model.name): \(imageCount) images"
                            }
                            .joined(separator: ", ")

                        return (successfulCount, imageStats)
                    }

                    self.logger.info("Enriched \(successfulEnrichments)/\(basicModels.count) models from \(community.id). Images: \(imageStats)")
                    return (community, enrichedModels)
                }
            }

            // Yield enriched results as they complete
            for await (community, enrichedModels) in enrichGroup {
                continuation.yield((community, enrichedModels))
            }
        }
    }
}
