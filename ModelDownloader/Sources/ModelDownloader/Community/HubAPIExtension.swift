import Abstractions
import Foundation

// MARK: - Community Models Search Extension

extension HubAPI {
    /// Search for models on HuggingFace
    /// - Parameters:
    ///   - query: Search query (searches in model name and tags)
    ///   - author: Filter by author/organization
    ///   - tags: Filter by specific tags
    ///   - sort: Sort option (downloads, likes, lastModified)
    ///   - direction: Sort direction
    ///   - limit: Maximum number of results (default 50, max 100)
    /// - Returns: Array of discovered models
    internal func searchModels(
        query: String? = nil,
        author: String? = nil,
        tags: [String]? = nil,
        sort: SortOption = .downloads,
        direction: SortDirection = .descending,
        limit: Int = 50
    ) async throws -> [DiscoveredModel] {
        var components: URLComponents = URLComponents(string: "\(endpoint)/api/models")!
        var queryItems: [URLQueryItem] = []

        // Build query parameters
        if let query {
            queryItems.append(URLQueryItem(name: "search", value: query))
        }

        if let author {
            queryItems.append(URLQueryItem(name: "author", value: author))
        }

        if let tags {
            for tag in tags {
                queryItems.append(URLQueryItem(name: "tags", value: tag))
            }
        }

        // Sort parameters
        queryItems.append(URLQueryItem(name: "sort", value: sort.apiValue))
        queryItems.append(URLQueryItem(name: "direction", value: String(direction.apiValue)))

        // Limit
        queryItems.append(URLQueryItem(name: "limit", value: String(min(limit, 100))))

        components.queryItems = queryItems

        guard let url = components.url else {
            await logger.error("Failed to construct search URL")
            throw HuggingFaceError.invalidURL
        }

        await logger.info("Searching models", metadata: [
            "query": query ?? "none",
            "author": author ?? "none",
            "tags": tags?.joined(separator: ",") ?? "none",
            "sort": sort.rawValue,
            "limit": limit
        ])

        // Build headers
        var headers: [String: String] = [:]
        if let token = await tokenManager.getToken() {
            headers["Authorization"] = "Bearer \(token)"
        }

        // Make request
        await logger.logAPIRequest(method: "GET", url: url, headers: headers)
        let startTime: Date = Date()
        let response: HTTPClientResponse = try await httpClient.get(url: url, headers: headers)
        let duration: TimeInterval = Date().timeIntervalSince(startTime)
        await logger.logAPIResponse(url: url, statusCode: response.statusCode, duration: duration)

        // Handle errors
        guard response.statusCode == 200 else {
            if response.statusCode == 401 {
                await logger.error("Authentication required for model search")
                throw HuggingFaceError.authenticationRequired
            }
            await logger.error("HTTP error searching models", metadata: [
                "statusCode": response.statusCode
            ])
            throw HuggingFaceError.httpError(statusCode: response.statusCode)
        }

        // Parse response
        let models: [DiscoveredModel] = try await parseModelsResponse(response.data)

        await logger.info("Model search completed", metadata: [
            "modelsFound": models.count
        ])

        return models
    }

    /// Search models with pagination support
    /// - Parameters:
    ///   - query: Search query
    ///   - author: Filter by author
    ///   - tags: Filter by tags
    ///   - sort: Sort option
    ///   - direction: Sort direction
    ///   - limit: Results per page
    ///   - cursor: Pagination cursor from previous page
    /// - Returns: Page of models with optional cursor for next page
    internal func searchModelsPaginated(
        query: String? = nil,
        author: String? = nil,
        tags: [String]? = nil,
        sort: SortOption = .downloads,
        direction: SortDirection = .descending,
        limit: Int = 50,
        cursor: String? = nil
    ) async throws -> ModelPage {
        var components: URLComponents = URLComponents(string: "\(endpoint)/api/models")!
        var queryItems: [URLQueryItem] = []

        // Same query building as searchModels
        if let query {
            queryItems.append(URLQueryItem(name: "search", value: query))
        }

        if let author {
            queryItems.append(URLQueryItem(name: "author", value: author))
        }

        if let tags {
            for tag in tags {
                queryItems.append(URLQueryItem(name: "tags", value: tag))
            }
        }

        queryItems.append(URLQueryItem(name: "sort", value: sort.apiValue))
        queryItems.append(URLQueryItem(name: "direction", value: String(direction.apiValue)))
        queryItems.append(URLQueryItem(name: "limit", value: String(min(limit, 100))))

        // Add cursor for pagination
        if let cursor {
            queryItems.append(URLQueryItem(name: "cursor", value: cursor))
        }

        components.queryItems = queryItems

        guard let url = components.url else {
            await logger.error("Failed to construct paginated search URL")
            throw HuggingFaceError.invalidURL
        }

        // Make request
        var headers: [String: String] = [:]
        if let token = await tokenManager.getToken() {
            headers["Authorization"] = "Bearer \(token)"
        }

        let response: HTTPClientResponse = try await httpClient.get(url: url, headers: headers)

        guard response.statusCode == 200 else {
            if response.statusCode == 401 {
                throw HuggingFaceError.authenticationRequired
            }
            throw HuggingFaceError.httpError(statusCode: response.statusCode)
        }

        // Parse paginated response
        return try await parsePaginatedResponse(response.data)
    }

    /// Get model card (README) content
    /// - Parameters:
    ///   - modelId: Model identifier (e.g., "mlx-community/model-name")
    ///   - revision: Git revision (default: "main")
    /// - Returns: Model card content as string, or nil if not found
    internal func getModelCard(
        modelId: String,
        revision: String = "main"
    ) async throws -> String? {
        let readmePath: String = "/\(modelId)/raw/\(revision)/README.md"
        let url: URL = URL(string: "\(endpoint)\(readmePath)")!

        await logger.debug("Fetching model card", metadata: [
            "modelId": modelId,
            "revision": revision
        ])

        var headers: [String: String] = [:]
        if let token = await tokenManager.getToken() {
            headers["Authorization"] = "Bearer \(token)"
        }

        let response: HTTPClientResponse = try await httpClient.get(url: url, headers: headers)

        if response.statusCode == 404 {
            await logger.debug("Model card not found", metadata: ["modelId": modelId])
            return nil
        }

        guard response.statusCode == 200 else {
            if response.statusCode == 401 {
                await logger.error("Authentication required for model card")
                throw HuggingFaceError.authenticationRequired
            }
            await logger.error("HTTP error fetching model card", metadata: [
                "modelId": modelId,
                "statusCode": response.statusCode
            ])
            throw HuggingFaceError.httpError(statusCode: response.statusCode)
        }

        guard let content: String = String(data: response.data, encoding: .utf8) else {
            await logger.error("Failed to decode model card as UTF-8")
            throw HuggingFaceError.invalidResponse
        }

        await logger.debug("Retrieved model card", metadata: [
            "modelId": modelId,
            "size": content.count
        ])

        return content
    }

    // MARK: - Private Parsing Helpers

    private func parseModelsResponse(_ data: Data) async throws -> [DiscoveredModel] {
        let decoder: JSONDecoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container: SingleValueDecodingContainer = try decoder.singleValueContainer()
            let string: String = try container.decode(String.self)

            let formatter: ISO8601DateFormatter = ISO8601DateFormatter()
            formatter.formatOptions = [
                .withInternetDateTime,
                .withFractionalSeconds
            ]

            if let date = formatter.date(from: string) {
                return date
            }

            // Try again without fractional seconds
            formatter.formatOptions = [.withInternetDateTime]

            guard let date = formatter.date(from: string) else {
                throw DecodingError.dataCorruptedError(
                    in: container,
                    debugDescription: "Invalid date: \(string)"
                )
            }

            return date
        }

        // Try parsing as array first (standard response)
        if let modelsArray = try? decoder.decode([HFModelResponse].self, from: data) {
            var discoveredModels: [DiscoveredModel] = []
            for response in modelsArray {
                if let model = await convertToDiscoveredModel(response) {
                    discoveredModels.append(model)
                }
            }
            return discoveredModels
        }

        // Try parsing as paginated response
        if let paginatedResponse = try? decoder.decode(HFPaginatedResponse.self, from: data) {
            var discoveredModels: [DiscoveredModel] = []
            for response in paginatedResponse.models {
                if let model = await convertToDiscoveredModel(response) {
                    discoveredModels.append(model)
                }
            }
            return discoveredModels
        }

        throw HuggingFaceError.invalidResponse
    }

    private func parsePaginatedResponse(_ data: Data) async throws -> ModelPage {
        let decoder: JSONDecoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container: SingleValueDecodingContainer = try decoder.singleValueContainer()
            let string: String = try container.decode(String.self)

            let formatter: ISO8601DateFormatter = ISO8601DateFormatter()
            formatter.formatOptions = [
                .withInternetDateTime,
                .withFractionalSeconds
            ]

            if let date = formatter.date(from: string) {
                return date
            }

            // Try again without fractional seconds
            formatter.formatOptions = [.withInternetDateTime]

            guard let date = formatter.date(from: string) else {
                throw DecodingError.dataCorruptedError(
                    in: container,
                    debugDescription: "Invalid date: \(string)"
                )
            }

            return date
        }

        if let response = try? decoder.decode(HFPaginatedResponse.self, from: data) {
            var discoveredModels: [DiscoveredModel] = []
            for modelResponse in response.models {
                if let model = await convertToDiscoveredModel(modelResponse) {
                    discoveredModels.append(model)
                }
            }
            return ModelPage(
                models: discoveredModels,
                hasNextPage: response.nextCursor != nil,
                nextPageToken: response.nextCursor,
                totalCount: nil
            )
        }

        // Fallback to non-paginated response
        if let modelsArray = try? decoder.decode([HFModelResponse].self, from: data) {
            var discoveredModels: [DiscoveredModel] = []
            for modelResponse in modelsArray {
                if let model = await convertToDiscoveredModel(modelResponse) {
                    discoveredModels.append(model)
                }
            }
            return ModelPage(
                models: discoveredModels,
                hasNextPage: false,
                nextPageToken: nil,
                totalCount: discoveredModels.count
            )
        }

        throw HuggingFaceError.invalidResponse
    }

    @MainActor
    private func convertToDiscoveredModel(_ response: HFModelResponse) async -> DiscoveredModel? {
        guard let modelId = response.modelId ?? response.id else {
            return nil
        }

        // Extract author from modelId
        let components: [Substring] = modelId.split(separator: "/")
        let author: String = components.count >= 2 ? String(components[0]) : "unknown"
        let name: String = components.count >= 2 ? String(components[1]) : modelId

        // Get file information with sizes from tree API
        await logger.debug("Fetching file info for model", metadata: ["modelId": modelId])
        let allFiles: [ModelFile] = await fetchFileInfoWithSizes(modelId: modelId)
        await logger.debug("Fetched files", metadata: [
            "modelId": modelId,
            "fileCount": allFiles.count,
            "totalSize": allFiles.compactMap(\.size).reduce(0, +)
        ])

        // Detect backends from files (use file-based detection since tags may be empty)
        let backendDetector: BackendDetector = BackendDetector()
        let detectedBackends: [SendableModel.Backend] = await backendDetector.detectBackends(from: allFiles)

        // Apply file selection based on detected backend to get accurate size calculation
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
        let license: String? = response.cardData?.license
        let licenseUrl: String? = license.flatMap { LicenseMapper.urlForLicense($0) }

        // Convert cardData to ModelCardData
        let modelCardData: ModelCardData? = response.cardData.map { cardData in
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

        await logger.debug("Converted model", metadata: [
            "id": modelId,
            "allFiles": allFiles.count,
            "selectedFiles": selectedFiles.count,
            "backends": detectedBackends.map(\SendableModel.Backend.rawValue),
            "totalSize": selectedFiles.compactMap(\.size).reduce(0, +),
            "hasCardData": modelCardData != nil,
            "hasThumbnail": modelCardData?.thumbnail != nil
        ])

        let discoveredModel: DiscoveredModel = DiscoveredModel(
            id: modelId,
            name: name,
            author: author,
            downloads: response.downloads ?? 0,
            likes: response.likes ?? 0,
            tags: response.tags ?? [], // Use tags from response when available
            lastModified: response.lastModified ?? Date(),
            files: selectedFiles, // Use selected files for accurate size calculation
            license: license,
            licenseUrl: licenseUrl,
            metadata: [:] // No longer storing license in metadata
        )

        // Enrich with progressive data
        let enrichedDetails: EnrichedModelDetails = EnrichedModelDetails(
            modelCard: nil, // Will be fetched separately if needed
            cardData: modelCardData,
            imageUrls: [], // Will be populated by ImageExtractor
            detectedBackends: detectedBackends // Now properly detected
        )
        discoveredModel.enrich(with: enrichedDetails)

        return discoveredModel
    }

    /// Fetch file information with sizes using the tree API
    private func fetchFileInfoWithSizes(modelId: String) async -> [ModelFile] {
        await logger.debug("fetchFileInfoWithSizes called", metadata: ["modelId": modelId])
        do {
            // Use recursive=true to get files in subdirectories
            let url: URL = URL(string: "\(endpoint)/api/models/\(modelId)/tree/main?recursive=true")!

            var headers: [String: String] = [:]
            if let token = await tokenManager.getToken() {
                headers["Authorization"] = "Bearer \(token)"
            }

            let response: HTTPClientResponse = try await httpClient.get(url: url, headers: headers)

            guard response.statusCode == 200 else {
                await logger.debug("Failed to fetch file tree", metadata: [
                    "modelId": modelId,
                    "statusCode": response.statusCode
                ])
                return []
            }

            // Parse tree response
            if let jsonArray = try? JSONSerialization.jsonObject(
                with: response.data,
                options: []
            ) as? [[String: Any]] {
                var files: [ModelFile] = []

                for item in jsonArray {
                    if let type = item["type"] as? String,
                       type == "file",
                       let path = item["path"] as? String {
                        // Get size (may be nil for some files)
                        let size: Int64?
                        if let sizeValue = item["size"] as? Int64 {
                            size = sizeValue
                        } else if let sizeValue = item["size"] as? Int {
                            size = Int64(sizeValue)
                        } else {
                            size = nil
                        }

                        files.append(ModelFile(path: path, size: size))
                    }
                }

                await logger.debug("Successfully fetched file tree", metadata: [
                    "modelId": modelId,
                    "filesCount": files.count,
                    "totalSize": files.compactMap(\.size).reduce(0, +)
                ])

                return files
            }
        } catch {
            await logger.error("Error fetching file tree", metadata: [
                "modelId": modelId,
                "error": String(describing: error)
            ])
        }

        await logger.debug("Returning empty array from fetchFileInfoWithSizes", metadata: ["modelId": modelId])
        return []
    }

    /// Fetch detailed model information including file sizes
    private func fetchDetailedModelInfo(modelId: String) async -> [ModelFile]? {
        let url: URL = URL(string: "\(endpoint)/api/models/\(modelId)")!

        do {
            var headers: [String: String] = [:]
            if let token = await tokenManager.getToken() {
                headers["Authorization"] = "Bearer \(token)"
            }

            let response: HTTPClientResponse = try await httpClient.get(url: url, headers: headers)

            guard response.statusCode == 200 else {
                await logger.debug("Failed to fetch detailed model info", metadata: [
                    "modelId": modelId,
                    "statusCode": response.statusCode
                ])
                return nil
            }

            // Parse the detailed response
            let decoder: JSONDecoder = JSONDecoder()
            decoder.dateDecodingStrategy = .custom { decoder in
                let container: SingleValueDecodingContainer = try decoder.singleValueContainer()
                let string: String = try container.decode(String.self)

                let formatter: ISO8601DateFormatter = ISO8601DateFormatter()
                formatter.formatOptions = [
                    .withInternetDateTime,
                    .withFractionalSeconds
                ]

                if let date = formatter.date(from: string) {
                    return date
                }

                // Try again without fractional seconds
                formatter.formatOptions = [.withInternetDateTime]

                guard let date = formatter.date(from: string) else {
                    throw DecodingError.dataCorruptedError(
                        in: container,
                        debugDescription: "Invalid date: \(string)"
                    )
                }

                return date
            }

            if let modelData = try? decoder.decode(HFDetailedModelResponse.self, from: response.data) {
                let files: [ModelFile] = (modelData.siblings ?? []).map { sibling in
                    ModelFile(
                        path: sibling.rfilename,
                        size: sibling.size
                    )
                }

                await logger.debug("Successfully fetched detailed model info", metadata: [
                    "modelId": modelId,
                    "filesCount": files.count,
                    "totalSize": files.compactMap(\.size).reduce(0, +)
                ])

                return files
            }
        } catch {
            await logger.debug("Error fetching detailed model info", metadata: [
                "modelId": modelId,
                "error": String(describing: error)
            ])
        }

        return nil
    }
}

// MARK: - API Response Models

/// HuggingFace model response structure
private struct HFModelResponse: Codable {
    let modelId: String?
    let id: String? // Sometimes the API uses 'id' instead of 'modelId'
    let author: String?
    let downloads: Int?
    let likes: Int?
    let tags: [String]?
    let lastModified: Date?
    let siblings: [HFSibling]?
    let cardData: CardData?
}

/// HuggingFace card data structure containing comprehensive metadata
internal struct CardData: Codable {
    // License information
    let license: String?
    let licenseName: String?
    let licenseLink: String?

    // Model relationships - can be either string or array
    let baseModel: [String]?
    let baseModelRelation: String?

    // Visual content
    let thumbnail: String?

    // Technical metadata
    let pipelineTag: String?
    let libraryName: String?
    let language: [String]?
    let datasets: [String]?
    let tags: [String]?

    // Additional gating information
    let extraGatedPrompt: String?
    let widget: [WidgetExample]?

    // Custom decoder to handle base_model as either string or array
    init(from decoder: Decoder) throws {
        let container: KeyedDecodingContainer<CodingKeys> = try decoder.container(keyedBy: CodingKeys.self)

        // Standard fields
        license = try container.decodeIfPresent(String.self, forKey: .license)
        licenseName = try container.decodeIfPresent(String.self, forKey: .licenseName)
        licenseLink = try container.decodeIfPresent(String.self, forKey: .licenseLink)
        baseModelRelation = try container.decodeIfPresent(String.self, forKey: .baseModelRelation)
        thumbnail = try container.decodeIfPresent(String.self, forKey: .thumbnail)
        pipelineTag = try container.decodeIfPresent(String.self, forKey: .pipelineTag)
        libraryName = try container.decodeIfPresent(String.self, forKey: .libraryName)
        language = try container.decodeIfPresent([String].self, forKey: .language)
        datasets = try container.decodeIfPresent([String].self, forKey: .datasets)
        tags = try container.decodeIfPresent([String].self, forKey: .tags)
        extraGatedPrompt = try container.decodeIfPresent(String.self, forKey: .extraGatedPrompt)
        widget = try container.decodeIfPresent([WidgetExample].self, forKey: .widget)

        // Handle baseModel as either string or array
        if let baseModelArray = try? container.decodeIfPresent([String].self, forKey: .baseModel) {
            baseModel = baseModelArray
        } else if let baseModelString = try? container.decodeIfPresent(String.self, forKey: .baseModel) {
            baseModel = [baseModelString]
        } else {
            baseModel = nil
        }
    }

    private enum CodingKeys: String, CodingKey {
        case license = "license"
        case licenseName = "license_name"
        case licenseLink = "license_link"
        case baseModel = "base_model"
        case baseModelRelation = "base_model_relation"
        case thumbnail = "thumbnail"
        case pipelineTag = "pipeline_tag"
        case libraryName = "library_name"
        case language = "language"
        case datasets = "datasets"
        case tags = "tags"
        case extraGatedPrompt = "extra_gated_prompt"
        case widget = "widget"
    }
}

/// Widget example structure for model cards
internal struct WidgetExample: Codable {
    let text: String?
    let exampleTitle: String?

    private enum CodingKeys: String, CodingKey {
        case text = "text"
        case exampleTitle = "example_title"
    }
}

/// HuggingFace file/sibling structure
internal struct HFSibling: Codable {
    let rfilename: String
    let size: Int64?
}

/// Paginated response structure
private struct HFPaginatedResponse: Codable {
    let models: [HFModelResponse]
    let nextCursor: String?
}

/// Detailed HuggingFace model response structure (individual model API)
internal struct HFDetailedModelResponse: Codable {
    let modelId: String?
    let id: String? // Sometimes the API uses 'id' instead of 'modelId'
    let author: String?
    let downloads: Int?
    let likes: Int?
    let tags: [String]?
    let lastModified: Date?
    let siblings: [HFSibling]?
    let cardData: CardData?
}

// MARK: - API Value Extensions

extension SortOption {
    /// API parameter value
    var apiValue: String {
        switch self {
        case .downloads:
            return "downloads"

        case .likes:
            return "likes"

        case .lastModified:
            return "lastModified"

        case .trending:
            return "trending"
        }
    }
}

extension SortDirection {
    /// API parameter value (-1 for descending, 1 for ascending)
    var apiValue: Int {
        switch self {
        case .ascending:
            return 1

        case .descending:
            return -1
        }
    }
}
