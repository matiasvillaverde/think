import Abstractions
import Foundation

/// Extracts image URLs from HuggingFace model cards and metadata
///
/// This actor provides thread-safe image extraction from model repositories,
/// implementing intelligent filtering and URL resolution. It follows the
/// enhanced strategy suggested in feedback:
/// 1. Check structured metadata first (config.json, cardData)
/// 2. Fall back to model card text parsing
/// 3. Apply smart filtering to exclude badges and logos
/// 4. Handle converted model references with recursion protection
actor ImageExtractor: ImageExtractorProtocol {
    private let hubAPI: HubAPI
    private let logger: ModelDownloaderLogger

    /// Initialize ImageExtractor with HubAPI dependency
    /// - Parameter hubAPI: HubAPI instance for network requests
    init(hubAPI: HubAPI = HubAPI()) {
        self.hubAPI = hubAPI
        self.logger = ModelDownloaderLogger(
            subsystem: "com.think.modeldownloader",
            category: "ImageExtractor"
        )
    }

    // MARK: - Image Extraction

    /// Extract image URLs from model metadata and card content
    func extractImageUrls(from modelId: String) async throws -> [String] {
        await logger.info("Extracting images", metadata: ["modelId": modelId])

        do {
            var allImages: [String] = []

            // Step 1: Try to get structured metadata first (includes thumbnail and base model images)
            if let structuredImages = try await extractFromStructuredMetadata(modelId: modelId) {
                allImages.append(contentsOf: structuredImages)
                await logger.info("Found images in structured metadata", metadata: [
                    "modelId": modelId,
                    "count": String(structuredImages.count)
                ])
            }

            // Step 2: Always also parse model card for additional images (CoreML models have many)
            let modelCard: String? = try await hubAPI.getModelCard(modelId: modelId)
            let cardImages: [String] = extractImageUrls(from: modelCard ?? "", modelId: modelId)

            // Add card images that aren't already in our list
            for cardImage in cardImages where !allImages.contains(cardImage) {
                allImages.append(cardImage)
            }

            // Step 3: If still no images found and this appears to be a converted model,
            // check the original model's metadata directly (non-recursive)
            if allImages.isEmpty {
                if let originalModelId = try await findOriginalModelId(from: modelId) {
                    await logger.info("Checking original model metadata", metadata: [
                        "convertedModel": modelId,
                        "originalModel": originalModelId
                    ])

                    // Get original model's structured metadata directly
                    if let originalModelInfo = try await getModelInfo(modelId: originalModelId),
                       let originalThumbnail = originalModelInfo.thumbnail,
                       !originalThumbnail.isEmpty {
                        allImages.append(originalThumbnail)
                        await logger.info("Found thumbnail in original model", metadata: [
                            "convertedModel": modelId,
                            "originalModel": originalModelId,
                            "thumbnail": originalThumbnail
                        ])
                    } else {
                        // If no structured images, also try the original model's card
                        let originalModelCard: String? = try await hubAPI.getModelCard(modelId: originalModelId)
                        let originalCardImages: [String] = extractImageUrls(
                            from: originalModelCard ?? "",
                            modelId: originalModelId
                        )

                        for originalImage in originalCardImages where !allImages.contains(originalImage) {
                            allImages.append(originalImage)
                        }

                        if !originalCardImages.isEmpty {
                            await logger.info("Found images in original model card", metadata: [
                                "convertedModel": modelId,
                                "originalModel": originalModelId,
                                "imageCount": String(originalCardImages.count)
                            ])
                        }
                    }
                }
            }

            // Step 4: If still no images found, use author avatar as fallback
            if allImages.isEmpty {
                if let authorAvatar = await getUserAvatar(for: modelId) {
                    allImages.append(authorAvatar)
                    await logger.info("Using author avatar as fallback", metadata: [
                        "modelId": modelId,
                        "avatar": authorAvatar
                    ])
                }
            }

            await logger.info("Extracted all images", metadata: [
                "modelId": modelId,
                "totalCount": String(allImages.count),
                "cardImages": String(cardImages.count)
            ])

            return allImages
        } catch {
            await logger.error("Failed to extract images", metadata: [
                "modelId": modelId,
                "error": error.localizedDescription
            ])
            throw ImageExtractionError.networkError(error.localizedDescription)
        }
    }

    /// Extract image URLs from model card content with intelligent filtering
    nonisolated func extractImageUrls(from modelCard: String, modelId: String) -> [String] {
        var imageUrls: [String] = []

        // Extract from markdown images: ![alt](url)
        imageUrls.append(contentsOf: extractMarkdownImages(from: modelCard, modelId: modelId))

        // Extract from HTML img tags: <img src="url">
        imageUrls.append(contentsOf: extractHTMLImages(from: modelCard, modelId: modelId))

        // Remove duplicates while preserving order
        var seen: Set<String> = Set<String>()
        return imageUrls.compactMap { url in
            if seen.contains(url) {
                return nil
            }
            seen.insert(url)
            return url
        }
    }

    // MARK: - Original Model Detection

    /// Find original model reference using structured metadata first
    func findOriginalModelId(from modelId: String) async throws -> String? {
        // Step 1: Check structured metadata for source model references
        if let structuredOriginal = try await findOriginalFromMetadata(modelId: modelId) {
            return structuredOriginal
        }

        // Step 2: Fall back to text parsing
        let modelCard: String? = try await hubAPI.getModelCard(modelId: modelId)
        return findOriginalModelId(from: modelCard)
    }

    /// Find original model reference from model card text patterns
    nonisolated func findOriginalModelId(from modelCard: String?) -> String? {
        guard let modelCard else { return nil }

        let patterns: [String] = [
            #"converted.*?from \[([a-zA-Z0-9-_]+/[a-zA-Z0-9-_.]+)\]"#,
            #"converted from ([a-zA-Z0-9-_]+/[a-zA-Z0-9-_.]+)"#,
            #"based on ([a-zA-Z0-9-_]+/[a-zA-Z0-9-_.]+)"#,
            #"MLX version of ([a-zA-Z0-9-_]+/[a-zA-Z0-9-_.]+)"#,
            #"conversion of ([a-zA-Z0-9-_]+/[a-zA-Z0-9-_.]+)"#,
            #"adapted from ([a-zA-Z0-9-_]+/[a-zA-Z0-9-_.]+)"#,
            #"fine-tuned from ([a-zA-Z0-9-_]+/[a-zA-Z0-9-_.]+)"#,
            #"Based on the original HuggingFace model: ([a-zA-Z0-9-_]+/[a-zA-Z0-9-_.]+)"#,
            #"Quantized version of ([a-zA-Z0-9-_]+/[a-zA-Z0-9-_.]+)"#,
            #"Original model: ([a-zA-Z0-9-_]+/[a-zA-Z0-9-_.]+)"#
        ]

        for pattern in patterns {
            do {
                let regex: NSRegularExpression = try NSRegularExpression(pattern: pattern, options: .caseInsensitive)
                let matches: [NSTextCheckingResult] = regex.matches(
                    in: modelCard,
                    range: NSRange(modelCard.startIndex..., in: modelCard)
                )

                if let match = matches.first,
                   let range = Range(match.range(at: 1), in: modelCard) {
                    return String(modelCard[range])
                }
            } catch {
                // Log error but continue with next pattern
                // Note: Cannot log from nonisolated context, pattern compilation errors are rare
                continue
            }
        }

        return nil
    }

    // MARK: - URL Resolution

    /// Resolve relative image URLs to absolute HuggingFace URLs
    nonisolated func resolveImageUrl(_ imagePath: String, for modelId: String) -> String {
        // If already absolute URL, return as-is
        if imagePath.hasPrefix("http://") || imagePath.hasPrefix("https://") {
            return imagePath
        }

        // Clean up the path
        var cleanPath: String = imagePath

        // Remove leading "./"
        if cleanPath.hasPrefix("./") {
            cleanPath = String(cleanPath.dropFirst(2))
        }

        // Remove leading "/"
        if cleanPath.hasPrefix("/") {
            cleanPath = String(cleanPath.dropFirst())
        }

        // Construct HuggingFace resolve URL
        return "https://huggingface.co/\(modelId)/resolve/main/\(cleanPath)"
    }

    // MARK: - Private Helper Methods

    /// Extract structured image references from metadata (config.json, cardData)
    private func extractFromStructuredMetadata(modelId: String) async throws -> [String]? {
        // Get model information to access cardData
        guard let modelInfo = try await getModelInfo(modelId: modelId) else {
            return nil
        }

        var structuredImages: [String] = []

        // Priority 1: Check for thumbnail in cardData
        if let thumbnail = modelInfo.thumbnail, !thumbnail.isEmpty {
            structuredImages.append(thumbnail)
            await logger.info("Found thumbnail in cardData", metadata: [
                "modelId": modelId,
                "thumbnail": thumbnail
            ])
        }

        // Priority 2: If no images found, check base models directly (non-recursive)
        if structuredImages.isEmpty, !modelInfo.baseModel.isEmpty {
            let baseModels: [String] = modelInfo.baseModel
            await logger.info("No thumbnail found, checking base models", metadata: [
                "modelId": modelId,
                "baseModels": baseModels.joined(separator: ", ")
            ])

            // Check each base model's metadata directly (no recursion)
            for baseModelId in baseModels {
                if let baseModelInfo = try await getModelInfo(modelId: baseModelId),
                   let baseThumbnail = baseModelInfo.thumbnail,
                   !baseThumbnail.isEmpty {
                    structuredImages.append(baseThumbnail)
                    await logger.info("Found thumbnail in base model", metadata: [
                        "modelId": modelId,
                        "baseModel": baseModelId,
                        "thumbnail": baseThumbnail
                    ])
                    break // Found an image, no need to check more base models
                }
            }
        }

        return structuredImages.isEmpty ? nil : structuredImages
    }

    /// Find original model from structured metadata
    private func findOriginalFromMetadata(modelId: String) async throws -> String? {
        // Get model information to access cardData
        guard let modelInfo = try await getModelInfo(modelId: modelId) else {
            return nil
        }

        // Check for base_model field in cardData
        if !modelInfo.baseModel.isEmpty,
           let firstBaseModel = modelInfo.baseModel.first {
            await logger.info("Found base model in cardData", metadata: [
                "modelId": modelId,
                "baseModel": firstBaseModel
            ])
            return firstBaseModel
        }

        return nil
    }

    /// Get model information including cardData from HubAPI
    private func getModelInfo(modelId: String) async throws -> ModelCardData? {
        // For now, we need to make a direct API call to get the model info
        // In a future refactor, this could be cached or passed from the caller
        let url: URL = URL(string: "https://huggingface.co/api/models/\(modelId)")!

        do {
            let (data, response): (Data, URLResponse) = try await URLSession.shared.data(from: url)

            guard let httpResponse: HTTPURLResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                await logger.warning("Failed to fetch model info", metadata: [
                    "modelId": modelId,
                    "statusCode": (response as? HTTPURLResponse)?.statusCode ?? -1
                ])
                return nil
            }

            // Parse the response to extract cardData
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let cardDataDict = json["cardData"] as? [String: Any] {
                // Convert dictionary to ModelCardData
                let cardData: Data = try JSONSerialization.data(withJSONObject: cardDataDict)
                let decoder: JSONDecoder = JSONDecoder()
                decoder.keyDecodingStrategy = .convertFromSnakeCase

                return try decoder.decode(ModelCardData.self, from: cardData)
            }

            return nil
        } catch {
            await logger.warning("Error fetching model info", metadata: [
                "modelId": modelId,
                "error": error.localizedDescription
            ])
            return nil
        }
    }

    /// Extract markdown image references using NSRegularExpression
    nonisolated private func extractMarkdownImages(from content: String, modelId: String) -> [String] {
        let pattern: String = #"!\[([^\]]*)\]\(([^)]+)\)"#

        do {
            let regex: NSRegularExpression = try NSRegularExpression(pattern: pattern, options: [])
            let matches: [NSTextCheckingResult] = regex.matches(
                in: content,
                range: NSRange(content.startIndex..., in: content)
            )

            return matches.compactMap { match in
                guard let altRange = Range(match.range(at: 1), in: content),
                      let urlRange = Range(match.range(at: 2), in: content) else {
                    return nil
                }

                let alt: String = String(content[altRange])
                let url: String = String(content[urlRange])

                // Apply intelligent filtering
                if shouldFilterImage(alt: alt, url: url) {
                    return nil
                }

                return resolveImageUrl(url, for: modelId)
            }
        } catch {
            return []
        }
    }

    /// Extract HTML img tag references using NSRegularExpression
    nonisolated private func extractHTMLImages(from content: String, modelId: String) -> [String] {
        let pattern: String = #"<img[^>]+src=["\']([^"\']+)["\'][^>]*(?:\salt=["\']([^"\']*)["\'])?"#

        do {
            let regex: NSRegularExpression = try NSRegularExpression(pattern: pattern, options: .caseInsensitive)
            let matches: [NSTextCheckingResult] = regex.matches(
                in: content,
                range: NSRange(content.startIndex..., in: content)
            )

            return matches.compactMap { match in
                guard let urlRange = Range(match.range(at: 1), in: content) else {
                    return nil
                }

                let url: String = String(content[urlRange])

                // Extract alt text if available
                var alt: String = ""
                if match.numberOfRanges > 2,
                   let altRange = Range(match.range(at: 2), in: content) {
                    alt = String(content[altRange])
                }

                // Apply intelligent filtering
                if shouldFilterImage(alt: alt, url: url) {
                    return nil
                }

                return resolveImageUrl(url, for: modelId)
            }
        } catch {
            return []
        }
    }

    /// Intelligent filtering to exclude badges, logos, and irrelevant images
    nonisolated private func shouldFilterImage(alt: String, url: String) -> Bool {
        let altLower: String = alt.lowercased()
        let urlLower: String = url.lowercased()

        // Filter terms for alt text and URLs (exclude generic badges/shields, not model logos)
        let filterTerms: [String] = [
            "shields.io", "img.shields.io", "travis-ci",
            "license", "download", "star", "fork", "build",
            "test", "coverage", "version"
        ]

        // Check alt text and URL for filter terms
        for term in filterTerms {
            if altLower.contains(term) || urlLower.contains(term) {
                return true
            }
        }

        // Filter "badge" specifically as a word boundary to avoid filtering "benchmark"
        let badgePattern: String = #"\bbadge\b"#
        if altLower.range(of: badgePattern, options: .regularExpression) != nil ||
           urlLower.range(of: badgePattern, options: .regularExpression) != nil {
            return true
        }

        // Filter CI/CD related patterns with word boundaries
        let cicdPatterns: [String] = [
            #"\bci\b"#,  // CI as whole word
            #"\bcd\b"#   // CD as whole word
        ]
        for pattern in cicdPatterns {
            if altLower.range(of: pattern, options: .regularExpression) != nil ||
               urlLower.range(of: pattern, options: .regularExpression) != nil {
                return true
            }
        }

        // Filter out generic icons/logos from common badge services, but allow model-specific logos
        let badgePatterns: [String] = [
            "github.com.*?/badges/",
            "img.shields.io",
            "travis-ci.org.*?\\.svg",
            "circleci.com.*?\\.svg"
        ]
        for pattern in badgePatterns where urlLower.range(of: pattern, options: .regularExpression) != nil {
            return true
        }

        // Filter PDF files (not images) but allow SVG logos
        if urlLower.hasSuffix(".pdf") {
            return true
        }

        // Filter SVG files only if they look like badges (shields.io, travis-ci, etc.)
        // Allow legitimate SVG logos like DeepSeek logo
        if urlLower.hasSuffix(".svg") {
            let svgBadgePatterns: [String] = [
                "shields.io", "travis-ci", "circleci", "appveyor",
                "codecov", "coveralls", "badge"
            ]
            for pattern in svgBadgePatterns where urlLower.contains(pattern) {
                return true
            }
            // Allow other SVG files (likely logos or diagrams)
        }

        // Filter very small dimensions if present in URL
        let dimensionPatterns: [String] = [
            #"\b\d{1,2}x\d{1,2}\b"#,  // e.g., "20x20"
            #"width=\d{1,2}"#,         // e.g., "width=16"
            #"height=\d{1,2}"#         // e.g., "height=16"
        ]

        for pattern in dimensionPatterns where urlLower.range(of: pattern, options: .regularExpression) != nil {
            return true
        }

        return false
    }

    /// Get user avatar URL as fallback when no model images are found
    private func getUserAvatar(for modelId: String) async -> String? {
        // Extract author from model ID
        let components: [Substring] = modelId.split(separator: "/")
        guard let author = components.first else { return nil }

        // Construct HuggingFace avatar URL
        // Format: https://cdn-avatars.huggingface.co/v1/production/uploads/{user_id}/{avatar_hash}.png
        // But we need the user info to get the actual avatar URL

        do {
            let userUrl: URL = URL(string: "https://huggingface.co/api/users/\(author)")!
            let (data, response): (Data, URLResponse) = try await URLSession.shared.data(from: userUrl)

            guard let httpResponse: HTTPURLResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                return nil
            }

            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let avatarUrl = json["avatarUrl"] as? String,
               !avatarUrl.isEmpty {
                await logger.info("Found user avatar", metadata: [
                    "author": String(author),
                    "avatarUrl": avatarUrl
                ])
                return avatarUrl
            }
        } catch {
            await logger.debug("Failed to fetch user avatar", metadata: [
                "author": String(author),
                "error": error.localizedDescription
            ])
        }

        return nil
    }
}
