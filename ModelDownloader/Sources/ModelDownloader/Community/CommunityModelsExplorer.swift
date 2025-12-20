import Abstractions
import Foundation

/// Main public interface for exploring and discovering AI models from HuggingFace communities
///
/// This facade provides a unified API for:
/// - Browsing models from different communities (mlx, lmstudio, coreml)
/// - Searching and filtering models
/// - Detecting supported backends
/// - Converting discovered models to downloadable format
///
/// Example usage:
/// ```swift
/// let explorer: CommunityModelsExplorer = CommunityModelsExplorer()
/// 
/// // Explore MLX community models
/// let models: Data = try await explorer.exploreCommunity(.mlxCommunity, query: "llama")
/// 
/// // Get specific model details
/// let model: Data = try await explorer.discoverModel("mlx-community/Llama-3.2-1B-4bit")
/// 
/// // Prepare for download
/// let sendableModel: Data = try await explorer.prepareForDownload(model)
/// ```
public actor CommunityModelsExplorer: CommunityModelsExplorerProtocol {
    private let hubAPI: HubAPI
    private let backendDetector: BackendDetector
    private let modelConverter: ModelConverter
    private let quantizationDetector: QuantizationDetector
    private let vramCalculator: VRAMCalculatorProtocol
    private let imageExtractor: ImageExtractorProtocol
    private let logger: ModelDownloaderLogger

    /// Initialize CommunityModelsExplorer
    public init() {
        let vramCalc: VRAMCalculator = VRAMCalculator()
        let hubAPIInstance: HubAPI = HubAPI()
        self.hubAPI = hubAPIInstance
        self.backendDetector = BackendDetector()
        self.modelConverter = ModelConverter()
        self.quantizationDetector = QuantizationDetector(vramCalculator: vramCalc)
        self.vramCalculator = vramCalc
        self.imageExtractor = ImageExtractor(hubAPI: hubAPIInstance)
        self.logger = ModelDownloaderLogger(
            subsystem: "com.think.modeldownloader",
            category: "CommunityModelsExplorer"
        )
    }

    /// Internal initializer for testing with custom HTTP client
    internal init(httpClient: HTTPClientProtocol) {
        let vramCalc: VRAMCalculator = VRAMCalculator()
        let hubAPIInstance: HubAPI = HubAPI(httpClient: httpClient)
        self.hubAPI = hubAPIInstance
        self.backendDetector = BackendDetector()
        self.modelConverter = ModelConverter()
        self.quantizationDetector = QuantizationDetector(vramCalculator: vramCalc)
        self.vramCalculator = vramCalc
        self.imageExtractor = ImageExtractor(hubAPI: hubAPIInstance)
        self.logger = ModelDownloaderLogger(
            subsystem: "com.think.modeldownloader",
            category: "CommunityModelsExplorer"
        )
    }

    /// Get the default model communities
    /// - Returns: Array of default communities (mlx, lmstudio, coreml)
    nonisolated public func getDefaultCommunities() -> [ModelCommunity] {
        ModelCommunity.defaultCommunities
    }

    /// Explore models from a specific community
    /// - Parameters:
    ///   - community: The community to explore
    ///   - query: Optional search query
    ///   - sort: Sort option (default: downloads)
    ///   - direction: Sort direction (default: descending)
    ///   - limit: Maximum results (default: 50)
    /// - Returns: Array of discovered models with detected backends
    public func exploreCommunity(
        _ community: ModelCommunity,
        query: String? = nil,
        sort: SortOption = .downloads,
        direction: SortDirection = .descending,
        limit: Int = 50
    ) async throws -> [DiscoveredModel] {
        await logger.info("Exploring community", metadata: [
            "community": community.id,
            "query": query ?? "none",
            "sort": sort.rawValue,
            "limit": limit
        ])

        // Search models in the community
        let models: [DiscoveredModel] = try await hubAPI.searchModels(
            query: query,
            author: community.id,
            sort: sort,
            direction: direction,
            limit: limit
        )

        // Detect backends for each model and enrich with supported backends
        var enhancedModels: [DiscoveredModel] = []
        for model in models {
            let backends: [SendableModel.Backend] = await backendDetector.detectBackends(
                from: model.tags,
                files: model.files
            )

            // Only include models with supported backends for this community
            let supportedBackends: [SendableModel.Backend] = backends.filter { backend in
                community.supportedBackends.contains(backend)
            }

            if !supportedBackends.isEmpty {
                await MainActor.run {
                    let enrichedDetails: EnrichedModelDetails = EnrichedModelDetails(
                        modelCard: model.modelCard,
                        cardData: model.cardData,
                        imageUrls: model.imageUrls,
                        detectedBackends: supportedBackends
                    )
                    model.enrich(with: enrichedDetails)
                }
                enhancedModels.append(model)
            }
        }

        await logger.info("Community exploration completed", metadata: [
            "community": community.id,
            "totalModels": models.count,
            "supportedModels": enhancedModels.count
        ])

        return enhancedModels
    }

    /// Discover a specific model by ID
    /// - Parameter modelId: Model identifier (e.g., "mlx-community/model-name")
    /// - Returns: Discovered model with backends detected and model card loaded
    public func discoverModel(_ modelId: String) async throws -> DiscoveredModel {
        await logger.info("Discovering model", metadata: ["modelId": modelId])

        // Parse model ID to get repository
        let components: [Substring] = modelId.split(separator: "/")
        guard components.count >= 2 else {
            await logger.error("Invalid model ID format", metadata: ["modelId": modelId])
            throw HuggingFaceError.invalidModel
        }

        let author: String = String(components[0])
        let name: String = components.dropFirst().joined(separator: "/")

        // Fetch detailed model information from HuggingFace API
        let detailedModelInfo: HFDetailedModelResponse = try await fetchDetailedModelInfo(for: modelId)

        // Get model card if available
        let modelCard: String? = try await hubAPI.getModelCard(modelId: modelId)

        // Create discovered model using the detailed API response
        let discoveredModel: DiscoveredModel = await convertDetailedResponseToDiscoveredModel(
            modelId: modelId,
            author: author,
            name: name,
            detailedInfo: detailedModelInfo,
            modelCard: modelCard
        )

        await logger.info("Model discovered", metadata: [
            "modelId": modelId,
            "originalFilesCount": discoveredModel.files.count,
            "selectedFilesCount": discoveredModel.files.count,
            "backends": discoveredModel.detectedBackends.map(\.rawValue),
            "downloads": discoveredModel.downloads,
            "likes": discoveredModel.likes,
            "tags": discoveredModel.tags.count
        ])

        return discoveredModel
    }

    /// Search models with pagination support
    /// - Parameters:
    ///   - query: Search query
    ///   - author: Filter by author
    ///   - tags: Filter by tags
    ///   - sort: Sort option
    ///   - direction: Sort direction
    ///   - limit: Results per page
    ///   - cursor: Pagination cursor
    /// - Returns: Page of models
    public func searchPaginated(
        query: String? = nil,
        author: String? = nil,
        tags: [String] = [],
        cursor: String? = nil,
        sort: SortOption = .downloads,
        direction: SortDirection = .descending,
        limit: Int = 30
    ) async throws -> ModelPage {
        await logger.info("Searching models with pagination", metadata: [
            "query": query ?? "none",
            "author": author ?? "none",
            "tags": tags.joined(separator: ",").isEmpty ? "none" : tags.joined(separator: ","),
            "cursor": cursor ?? "none"
        ])

        let page: ModelPage = try await hubAPI.searchModelsPaginated(
            query: query,
            author: author,
            tags: tags,
            sort: sort,
            direction: direction,
            limit: limit,
            cursor: cursor
        )

        // Enhance models with backend detection
        var enhancedModels: [DiscoveredModel] = []
        for model in page.models {
            let backends: [SendableModel.Backend] = await backendDetector.detectBackends(from: model.files)
            await MainActor.run {
                let enrichedDetails: EnrichedModelDetails = EnrichedModelDetails(
                    modelCard: model.modelCard,
                    cardData: model.cardData,
                    imageUrls: model.imageUrls,
                    detectedBackends: backends
                )
                model.enrich(with: enrichedDetails)
            }
            enhancedModels.append(model)
        }

        return ModelPage(
            models: enhancedModels,
            hasNextPage: page.hasNextPage,
            nextPageToken: page.nextPageToken,
            totalCount: page.totalCount
        )
    }

    /// Search models by tags
    /// - Parameters:
    ///   - tags: Tags to search for
    ///   - community: Optional community filter
    ///   - sort: Sort option
    ///   - limit: Maximum results
    /// - Returns: Array of discovered models
    public func searchByTags(
        _ tags: [String],
        community: ModelCommunity? = nil,
        sort: SortOption = .downloads,
        limit: Int = 50
    ) async throws -> [DiscoveredModel] {
        await logger.info("Searching by tags", metadata: [
            "tags": tags.joined(separator: ","),
            "community": community?.id ?? "all"
        ])

        let models: [DiscoveredModel] = try await hubAPI.searchModels(
            author: community?.id,
            tags: tags,
            sort: sort,
            limit: limit
        )

        // Enhance with backend detection
        var enhancedModels: [DiscoveredModel] = []
        for model in models {
            let backends: [SendableModel.Backend] = await backendDetector.detectBackends(from: model.files)

            // Filter by community supported backends if specified
            if let community {
                let supportedBackends: [SendableModel.Backend] = backends.filter { backend in
                    community.supportedBackends.contains(backend)
                }
                if !supportedBackends.isEmpty {
                    await MainActor.run {
                        let enrichedDetails: EnrichedModelDetails = EnrichedModelDetails(
                            modelCard: model.modelCard,
                            cardData: model.cardData,
                            imageUrls: model.imageUrls,
                            detectedBackends: supportedBackends
                        )
                        model.enrich(with: enrichedDetails)
                    }
                    enhancedModels.append(model)
                }
            } else {
                await MainActor.run {
                    let enrichedDetails: EnrichedModelDetails = EnrichedModelDetails(
                        modelCard: model.modelCard,
                        cardData: model.cardData,
                        imageUrls: model.imageUrls,
                        detectedBackends: backends
                    )
                    model.enrich(with: enrichedDetails)
                }
                enhancedModels.append(model)
            }
        }

        return enhancedModels
    }

    /// Convert a discovered model to SendableModel for download
    /// - Parameters:
    ///   - model: The discovered model
    ///   - preferredBackend: Optional preferred backend
    /// - Returns: SendableModel ready for download
    public func prepareForDownload(
        _ model: DiscoveredModel,
        preferredBackend: SendableModel.Backend? = nil
    ) async throws -> SendableModel {
        await logger.info("Preparing model for download", metadata: [
            "modelId": model.id,
            "preferredBackend": preferredBackend?.rawValue ?? "auto"
        ])

        return try await modelConverter.toSendableModel(model, preferredBackend: preferredBackend)
    }

    /// Get model info preview without downloading
    /// - Parameter model: The discovered model
    /// - Returns: ModelInfo for preview
    public func getModelPreview(_ model: DiscoveredModel) async -> ModelInfo {
        await modelConverter.toModelInfo(model)
    }

    // MARK: - Multi-Quantization Support

    /// Get all available quantizations for a model
    /// - Parameters:
    ///   - model: The discovered model
    ///   - parameters: Optional parameter count for accurate calculations
    /// - Returns: Array of quantization options with memory requirements
    @preconcurrency
    @MainActor
    public func getAvailableQuantizations(
        for model: DiscoveredModel,
        parameters: UInt64? = nil
    ) async -> [QuantizationInfo] {
        await logger.info("Getting available quantizations", metadata: [
            "modelId": model.id,
            "fileCount": model.files.count
        ])

        return quantizationDetector.detectQuantizations(in: model, parameters: parameters)
    }

    /// Prepare model for download with specific quantization
    /// - Parameters:
    ///   - model: The discovered model
    ///   - quantization: Specific quantization to use
    ///   - preferredBackend: Optional preferred backend
    /// - Returns: SendableModel with detailed memory requirements
    @preconcurrency
    @MainActor
    public func prepareForDownloadWithQuantization(
        _ model: DiscoveredModel,
        quantization: QuantizationInfo,
        preferredBackend: SendableModel.Backend? = nil
    ) async throws -> SendableModel {
        await logger.info("Preparing model with specific quantization", metadata: [
            "modelId": model.id,
            "quantization": quantization.level.rawValue,
            "fileSize": quantization.fileSize
        ])

        // Create base sendable model
        let sendableModel: SendableModel = try await modelConverter.toSendableModel(
            model,
            preferredBackend: preferredBackend
        )

        // Extract model metadata with version
        let (architecture, version): (Architecture, String?) = Architecture.detectWithVersion(
            from: model.name,
            tags: model.tags
        )
        let parameters: ModelParameters = ModelParameters.fromString(model.name) ?? ModelParameters(
            count: 0,
            formatted: "Unknown"
        )
        let capabilities: Set<Capability> = detectCapabilities(from: model.tags)

        // Create model metadata with quantization info
        let metadata: Abstractions.ModelMetadata = Abstractions.ModelMetadata(
            parameters: parameters,
            architecture: architecture,
            capabilities: capabilities,
            quantizations: [quantization],
            version: version,
            contextLength: extractContextLength(from: model.modelCard),
            license: model.license
        )

        // Create new SendableModel with detailed memory requirements
        return SendableModel(
            id: sendableModel.id,
            ramNeeded: quantization.memoryRequirements?.totalMemory ?? sendableModel.ramNeeded,
            modelType: sendableModel.modelType,
            location: sendableModel.location,
            architecture: sendableModel.architecture,
            backend: sendableModel.backend,
            detailedMemoryRequirements: quantization.memoryRequirements,
            metadata: metadata
        )
    }

    /// Get best quantization for available memory
    /// - Parameters:
    ///   - model: The discovered model
    ///   - availableMemory: Available memory in bytes
    ///   - minimumQuality: Minimum quality level (0.0-1.0)
    /// - Returns: Best quantization that fits, or nil
    public func getBestQuantization(
        for model: DiscoveredModel,
        availableMemory: UInt64,
        minimumQuality: Double = 0.3
    ) async -> QuantizationInfo? {
        let quantizations: [QuantizationInfo] = await getAvailableQuantizations(for: model)

        // Filter by minimum quality and memory constraints
        let suitable: [QuantizationInfo] = quantizations.filter { quant in
            guard quant.qualityScore >= minimumQuality,
                  let memReq = quant.memoryRequirements else {
                return false
            }
            return memReq.totalMemory <= availableMemory
        }

        // Return highest quality that fits
        return suitable.max { $0.qualityScore < $1.qualityScore }
    }

    // MARK: - Helper Methods

    nonisolated private func detectCapabilities(from tags: [String]) -> Set<Capability> {
        var capabilities: Set<Capability> = Set<Capability>()

        let tagString: String = tags.joined(separator: " ").lowercased()

        if tagString.contains("text-generation") { capabilities.insert(.textGeneration) }
        if tagString.contains("instruct") { capabilities.insert(.instructFollowing) }
        if tagString.contains("code") || tagString.contains("coding") { capabilities.insert(.coding) }
        if tagString.contains("math") { capabilities.insert(.mathematics) }
        if tagString.contains("vision") || tagString.contains("multimodal") { capabilities.insert(.vision) }
        if tagString.contains("tool") || tagString.contains("function") { capabilities.insert(.toolUse) }
        if tagString.contains("multilingual") { capabilities.insert(.multilingualSupport) }
        if tagString.contains("reasoning") { capabilities.insert(.reasoning) }

        // Default capability
        if capabilities.isEmpty, tagString.contains("language-model") {
            capabilities.insert(.textGeneration)
        }

        return capabilities
    }

    nonisolated private func extractContextLength(from modelCard: String?) -> Int? {
        guard let card = modelCard else { return nil }

        // Common patterns for context length
        let patterns: [String] = [
            #"context[_ ](?:length|size|window)[:\s]*(\d+)k?"#,
            #"(\d+)k?\s*(?:tokens?\s*)?context"#,
            #"max[_ ](?:sequence|seq)[_ ](?:length|len)[:\s]*(\d+)"#
        ]

        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
                let range: NSRange = NSRange(card.startIndex..<card.endIndex, in: card)
                if let match: NSTextCheckingResult = regex.firstMatch(in: card, options: [], range: range) {
                    if let numberRange = Range(match.range(at: 1), in: card) {
                        let numberStr: String = String(card[numberRange])
                        if let value: Int = Int(numberStr) {
                            // Check if it's in K notation
                            if card[numberRange.upperBound...].starts(with: "k") {
                                return value * 1_024
                            }
                            return value
                        }
                    }
                }
            }
        }

        return nil
    }

    // MARK: - Helper Methods for discoverModel

    /// Fetch detailed model information from HuggingFace API
    private func fetchDetailedModelInfo(for modelId: String) async throws -> HFDetailedModelResponse {
        let url: URL = URL(string: "\(hubAPI.endpoint)/api/models/\(modelId)")!

        await logger.debug("Fetching detailed model info", metadata: ["modelId": modelId])

        let headers: [String: String] = [:]
        // Access the token manager through hubAPI (internal access)
        let response: HTTPClientResponse = try await hubAPI.httpGet(url: url, headers: headers)

        guard response.statusCode == 200 else {
            if response.statusCode == 404 {
                await logger.error("Model not found", metadata: ["modelId": modelId])
                throw HuggingFaceError.repositoryNotFound
            }
            await logger.error("HTTP error fetching detailed model info", metadata: [
                "modelId": modelId,
                "statusCode": response.statusCode
            ])
            throw HuggingFaceError.httpError(statusCode: response.statusCode)
        }

        // Parse the detailed response
        let decoder: JSONDecoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container: SingleValueDecodingContainer = try decoder.singleValueContainer()
            let string: String = try container.decode(String.self)

            let formatter: ISO8601DateFormatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

            if let date = formatter.date(from: string) {
                return date
            }

            // Try again without fractional seconds
            formatter.formatOptions = [.withInternetDateTime]

            guard let date: Date = formatter.date(from: string) else {
                throw DecodingError.dataCorruptedError(
                    in: container,
                    debugDescription: "Invalid date: \(string)"
                )
            }

            return date
        }

        do {
            let detailedResponse: HFDetailedModelResponse = try decoder.decode(
                HFDetailedModelResponse.self,
                from: response.data
            )
            await logger.debug("Successfully fetched detailed model info", metadata: [
                "modelId": modelId,
                "downloads": detailedResponse.downloads ?? 0,
                "likes": detailedResponse.likes ?? 0,
                "tags": detailedResponse.tags?.count ?? 0,
                "filesCount": detailedResponse.siblings?.count ?? 0
            ])
            return detailedResponse
        } catch {
            await logger.error("Failed to decode detailed model response", metadata: [
                "modelId": modelId,
                "error": String(describing: error)
            ])
            throw HuggingFaceError.invalidResponse
        }
    }

    /// Convert detailed HuggingFace response to DiscoveredModel
    @MainActor
    private func convertDetailedResponseToDiscoveredModel(
        modelId: String,
        author: String,
        name: String,
        detailedInfo: HFDetailedModelResponse,
        modelCard: String?
    ) async -> DiscoveredModel {
        await logger.debug("Converting detailed response to DiscoveredModel", metadata: ["modelId": modelId])

        // Get file information from siblings
        var allFiles: [ModelFile] = (detailedInfo.siblings ?? []).map { sibling in
            ModelFile(path: sibling.rfilename, size: sibling.size)
        }

        // If any files are missing size information, fetch complete file list
        if allFiles.contains(where: { $0.size == nil }) {
            await logger.debug(
                "Some files missing size info, fetching complete file list",
                metadata: ["modelId": modelId]
            )

            // Create repository object for API call
            let repo: Repository = Repository(id: modelId)

            // Fetch complete file information with sizes
            if let completeFiles = try? await hubAPI.listFiles(repo: repo) {
                // Convert FileInfo to ModelFile
                allFiles = completeFiles.map { fileInfo in
                    ModelFile(path: fileInfo.path, size: fileInfo.size)
                }
                await logger.debug("Fetched complete file list", metadata: [
                    "modelId": modelId,
                    "filesCount": allFiles.count
                ])
            }
        }

        // Detect backends from files
        let detectedBackends: [SendableModel.Backend] = await backendDetector.detectBackends(from: allFiles)

        // Apply file selection based on detected backend
        var selectedFiles: [ModelFile] = allFiles
        if let primaryBackend = detectedBackends.first {
            let fileSelectorFactory: FileSelectorFactory = FileSelectorFactory.shared
            if let fileSelector = await fileSelectorFactory.createSelector(for: primaryBackend) {
                selectedFiles = await fileSelector.selectFiles(from: allFiles)
                await logger.debug("Applied file selection", metadata: [
                    "backend": primaryBackend.rawValue,
                    "originalFiles": allFiles.count,
                    "selectedFiles": selectedFiles.count
                ])
            }
        }

        // Extract license information
        let license: String? = detailedInfo.cardData?.license
        let licenseUrl: String? = license.flatMap { LicenseMapper.urlForLicense($0) }

        // Convert cardData to ModelCardData
        let modelCardData: ModelCardData? = detailedInfo.cardData.map { cardData in
            ModelCardData(
                license: cardData.license,
                licenseName: cardData.licenseName,
                licenseLink: cardData.licenseLink,
                baseModel: cardData.baseModel ?? [],
                baseModelRelation: cardData.baseModelRelation,
                thumbnail: cardData.thumbnail,
                pipelineTag: cardData.pipelineTag,
                libraryName: cardData.libraryName,
                language: cardData.language ?? [],
                datasets: cardData.datasets ?? [],
                tags: cardData.tags ?? [],
                extraGatedPrompt: cardData.extraGatedPrompt,
                widget: cardData.widget?.map { widget in
                    Abstractions.WidgetExample(text: widget.text, exampleTitle: widget.exampleTitle)
                } ?? []
            )
        }

        await logger.debug("Converted detailed model", metadata: [
            "id": modelId,
            "downloads": detailedInfo.downloads ?? 0,
            "likes": detailedInfo.likes ?? 0,
            "tags": detailedInfo.tags?.count ?? 0,
            "allFiles": allFiles.count,
            "selectedFiles": selectedFiles.count,
            "backends": detectedBackends.map(\.rawValue),
            "hasCardData": modelCardData != nil,
            "hasThumbnail": modelCardData?.thumbnail != nil
        ])

        let discoveredModel: DiscoveredModel = DiscoveredModel(
            id: modelId,
            name: name,
            author: author,
            downloads: detailedInfo.downloads ?? 0,
            likes: detailedInfo.likes ?? 0,
            tags: detailedInfo.tags ?? [],
            lastModified: detailedInfo.lastModified ?? Date(),
            files: selectedFiles,
            license: license,
            licenseUrl: licenseUrl,
            metadata: [:]
        )

        // Enrich with progressive data
        let enrichedDetails: EnrichedModelDetails = EnrichedModelDetails(
            modelCard: modelCard,
            cardData: modelCardData,
            imageUrls: [], // Will be populated by ImageExtractor
            detectedBackends: detectedBackends
        )
        discoveredModel.enrich(with: enrichedDetails)

        return discoveredModel
    }

    // MARK: - Model Enhancement

    /// Enrich a model with complete data including model card and images
    /// This method takes a basic DiscoveredModel (from search results) and enhances it
    /// with detailed information fetched from the HuggingFace API
    /// - Parameter model: Basic model from search results
    /// - Returns: Enhanced model with complete data
    @preconcurrency
    @MainActor
    public func enrichModel(_ model: DiscoveredModel) async -> DiscoveredModel {
        await logger.info("Enriching model with detailed data", metadata: ["modelId": model.id])

        // If model already has complete data, return as-is
        if model.modelCard != nil, model.cardData != nil,
           !model.imageUrls.isEmpty {
            await logger.debug("Model already enriched, skipping", metadata: ["modelId": model.id])
            return model
        }

        // Use discoverModel to get complete data
        do {
            let enrichedModel: DiscoveredModel = try await discoverModel(model.id)

            // Also populate images using ImageExtractor
            let fullyEnrichedModel: DiscoveredModel = await populateImages(for: enrichedModel)

            await logger.info("Successfully enriched model", metadata: [
                "modelId": model.id,
                "hasModelCard": fullyEnrichedModel.modelCard != nil,
                "hasCardData": fullyEnrichedModel.cardData != nil,
                "hasImages": !fullyEnrichedModel.imageUrls.isEmpty,
                "imageCount": fullyEnrichedModel.imageUrls.count
            ])

            return fullyEnrichedModel
        } catch {
            await logger.error("Failed to enrich model, returning original", metadata: [
                "modelId": model.id,
                "error": String(describing: error)
            ])

            // Return original model if enrichment fails
            return model
        }
    }

    /// Enrich multiple models concurrently with detailed data
    /// - Parameter models: Array of basic models from search results
    /// - Returns: Array of enhanced models with complete data
    public func enrichModels(_ models: [DiscoveredModel]) async -> [DiscoveredModel] {
        await logger.info("Enriching multiple models", metadata: ["count": models.count])

        let enrichedModels: [DiscoveredModel] = await withTaskGroup(of: DiscoveredModel.self) { group in
            // Add enrichment tasks for each model
            for model in models {
                group.addTask {
                    await self.enrichModel(model)
                }
            }

            // Collect results
            var results: [DiscoveredModel] = []
            for await enrichedModel in group {
                results.append(enrichedModel)
            }
            return results
        }

        await logger.info("Completed enriching multiple models", metadata: [
            "originalCount": models.count,
            "enrichedCount": enrichedModels.count
        ])

        return enrichedModels
    }

    // MARK: - Image Enhancement

    /// Populate image URLs for a discovered model with lazy loading
    @preconcurrency
    @MainActor
    public func populateImages(for model: DiscoveredModel) async -> DiscoveredModel {
        await logger.info("Populating images for model", metadata: ["modelId": model.id])

        do {
            let imageUrls: [String] = try await imageExtractor.extractImageUrls(from: model.id)

            await logger.info("Successfully extracted images", metadata: [
                "modelId": model.id,
                "imageCount": String(imageUrls.count)
            ])

            // Enrich the model with populated images
            let enrichedDetails: EnrichedModelDetails = EnrichedModelDetails(
                modelCard: model.modelCard,
                cardData: model.cardData,
                imageUrls: imageUrls,
                detectedBackends: model.detectedBackends
            )
            model.enrich(with: enrichedDetails)

            return model
        } catch {
            await logger.error("Failed to populate images", metadata: [
                "modelId": model.id,
                "error": error.localizedDescription
            ])

            // Enrich model with empty image array to indicate attempt was made
            let enrichedDetails: EnrichedModelDetails = EnrichedModelDetails(
                modelCard: model.modelCard,
                cardData: model.cardData,
                imageUrls: [],
                detectedBackends: model.detectedBackends
            )
            model.enrich(with: enrichedDetails)

            return model
        }
    }
}
