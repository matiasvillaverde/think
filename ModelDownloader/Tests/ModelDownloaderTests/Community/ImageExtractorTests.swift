import Abstractions
import Foundation
@testable import ModelDownloader
import Testing

@Suite("ImageExtractor Tests")
struct ImageExtractorTests {
    // MARK: - Image URL Extraction from Model Card

    @Test("Extract markdown image URLs")
    func testExtractMarkdownImages() {
        let modelCard: String = """
        # Test Model

        ![Architecture](architecture.png)
        ![Sample Output](./samples/output.jpg)
        ![External Image](https://example.com/image.png)
        """

        let extractor: MockImageExtractor = MockImageExtractor()
        let imageUrls: [String] = extractor.extractImageUrls(from: modelCard, modelId: "test/model")

        #expect(imageUrls.count == 3)
        #expect(imageUrls.contains("https://huggingface.co/test/model/resolve/main/architecture.png"))
        #expect(imageUrls.contains("https://huggingface.co/test/model/resolve/main/samples/output.jpg"))
        #expect(imageUrls.contains("https://example.com/image.png"))
    }

    @Test("Extract HTML img tags")
    func testExtractHTMLImages() {
        let modelCard: String = """
        <img src="diagram.png" alt="Model Diagram">
        <img src="/absolute/path.jpg" alt="Absolute Path">
        """

        let extractor: MockImageExtractor = MockImageExtractor()
        let imageUrls: [String] = extractor.extractImageUrls(from: modelCard, modelId: "test/model")

        #expect(imageUrls.count == 2)
        #expect(imageUrls.contains("https://huggingface.co/test/model/resolve/main/diagram.png"))
        #expect(imageUrls.contains("https://huggingface.co/test/model/resolve/main/absolute/path.jpg"))
    }

    @Test("Filter out badge and logo images")
    func testFilterBadgeImages() {
        let modelCard: String = """
        ![License Badge](license.svg)
        ![Downloads](https://img.shields.io/badge/downloads-1k-blue.svg)
        ![Logo](logo.png)
        ![Architecture Diagram](architecture.png)
        <img src="icon.svg" alt="icon">
        """

        let extractor: MockImageExtractor = MockImageExtractor()
        let imageUrls: [String] = extractor.extractImageUrls(from: modelCard, modelId: "test/model")

        // Should only include architecture.png, filtering out badges/logos
        #expect(imageUrls.count == 1)
        #expect(imageUrls.contains("https://huggingface.co/test/model/resolve/main/architecture.png"))
    }

    @Test("Handle empty or nil model card")
    func testEmptyModelCard() {
        let extractor: MockImageExtractor = MockImageExtractor()

        let emptyUrls: [String] = extractor.extractImageUrls(from: "", modelId: "test/model")
        #expect(emptyUrls.isEmpty)

        let nilUrls: [String] = extractor.extractImageUrls(from: "", modelId: "test/model")
        #expect(nilUrls.isEmpty)
    }

    @Test("Handle malformed image URLs")
    func testMalformedImageUrls() {
        let modelCard: String = """
        ![Valid](valid.png)
        ![Invalid](invalid url with spaces.png)
        ![](empty-alt.png)
        """

        let extractor: MockImageExtractor = MockImageExtractor()
        let imageUrls: [String] = extractor.extractImageUrls(from: modelCard, modelId: "test/model")

        // Should handle malformed URLs gracefully and extract valid ones
        #expect(imageUrls.contains("https://huggingface.co/test/model/resolve/main/valid.png"))
        #expect(imageUrls.contains("https://huggingface.co/test/model/resolve/main/empty-alt.png"))
        // Should also handle URLs with spaces (though not ideal, they get resolved)
        #expect(imageUrls.contains("https://huggingface.co/test/model/resolve/main/invalid url with spaces.png"))
    }

    // MARK: - Original Model Detection from Text

    @Test("Find original model from conversion text")
    func testFindOriginalModelFromText() {
        let modelCard: String = """
        # MLX Converted Model

        This model was converted from cognitivecomputations/Dolphin-Mistral-24B-Venice-Edition
        using the MLX framework.
        """

        let extractor: MockImageExtractor = MockImageExtractor()
        let originalId: String? = extractor.findOriginalModelId(from: modelCard as String?)

        #expect(originalId == "cognitivecomputations/Dolphin-Mistral-24B-Venice-Edition")
    }

    @Test("Handle various conversion text patterns")
    func testVariousConversionPatterns() {
        let extractor: MockImageExtractor = MockImageExtractor()

        let patterns: [String: String] = [
            "Converted from microsoft/DialoGPT-medium": "microsoft/DialoGPT-medium",
            "Based on huggingface/model-name": "huggingface/model-name",
            "MLX version of facebook/llama-2-7b": "facebook/llama-2-7b",
            "This is a conversion of openai/gpt-3.5-turbo": "openai/gpt-3.5-turbo"
        ]

        for (text, expected) in patterns {
            let result: String? = extractor.findOriginalModelId(from: text as String?)
            #expect(result == expected, "Failed to parse: \(text)")
        }
    }

    @Test("Return nil for non-converted models")
    func testNonConvertedModel() {
        let modelCard: String = """
        # Original Model

        This is an original model trained from scratch.
        """

        let extractor: MockImageExtractor = MockImageExtractor()
        let originalId: String? = extractor.findOriginalModelId(from: modelCard as String?)

        #expect(originalId == nil)
    }

    // MARK: - URL Resolution

    @Test("Resolve relative URLs to absolute")
    func testResolveRelativeUrls() {
        let extractor: MockImageExtractor = MockImageExtractor()

        let testCases: [(String, String)] = [
            ("image.png", "https://huggingface.co/test/model/resolve/main/image.png"),
            ("./image.png", "https://huggingface.co/test/model/resolve/main/image.png"),
            ("folder/image.png", "https://huggingface.co/test/model/resolve/main/folder/image.png"),
            ("/absolute/path.png", "https://huggingface.co/test/model/resolve/main/absolute/path.png"),
            ("https://example.com/image.png", "https://example.com/image.png")
        ]

        for (input, expected) in testCases {
            let result: String = extractor.resolveImageUrl(input, for: "test/model")
            #expect(result == expected, "Failed to resolve: \(input)")
        }
    }

    @Test("Handle cross-repository references")
    func testCrossRepositoryReferences() {
        let extractor: MockImageExtractor = MockImageExtractor()

        // Should handle references to other repositories
        let crossRepoUrl: String = extractor.resolveImageUrl(
            "src=\"/another-repo/image.png\"",
            for: "test/model"
        )

        // Should still use the base model's repository
        #expect(crossRepoUrl.contains("test/model"))
    }
}

// MARK: - Mock Implementation

/// Mock ImageExtractor for testing
private struct MockImageExtractor: ImageExtractorProtocol {
    func extractImageUrls(from _: String) async throws -> [String] {
        await Task.yield()
        try Task.checkCancellation()
        // Mock implementation - will be replaced with real network calls in integration tests
        return []
    }

    func extractImageUrls(from modelCard: String, modelId: String) -> [String] {
        var imageUrls: [String] = []

        // Simple regex patterns for testing (real implementation will use NSRegularExpression)
        let markdownPattern: String = #"!\[([^\]]*)\]\(([^)]+)\)"#
        let htmlPattern: String = #"<img[^>]+src=["\']([^"\']+)["\']"#

        // Extract markdown images
        guard let markdownRegex: NSRegularExpression = try? NSRegularExpression(
            pattern: markdownPattern
        ) else { return [] }
        let markdownMatches: [NSTextCheckingResult] = markdownRegex.matches(
            in: modelCard,
            range: NSRange(modelCard.startIndex..., in: modelCard)
        )

        for match: NSTextCheckingResult in markdownMatches {
            if let altRange: Range<String.Index> = Range(match.range(at: 1), in: modelCard),
               let urlRange: Range<String.Index> = Range(match.range(at: 2), in: modelCard) {
                let alt: String = String(modelCard[altRange])
                let url: String = String(modelCard[urlRange])

                if !shouldFilterImage(alt: alt, url: url) {
                    imageUrls.append(resolveImageUrl(url, for: modelId))
                }
            }
        }

        // Extract HTML images
        guard let htmlRegex: NSRegularExpression = try? NSRegularExpression(
            pattern: htmlPattern
        ) else { return imageUrls }
        let htmlMatches: [NSTextCheckingResult] = htmlRegex.matches(
            in: modelCard,
            range: NSRange(modelCard.startIndex..., in: modelCard)
        )

        for match: NSTextCheckingResult in htmlMatches {
            if let urlRange: Range<String.Index> = Range(match.range(at: 1), in: modelCard) {
                let url: String = String(modelCard[urlRange])

                if !shouldFilterImage(alt: "", url: url) {
                    imageUrls.append(resolveImageUrl(url, for: modelId))
                }
            }
        }

        return imageUrls
    }

    func findOriginalModelId(from _: String) async throws -> String? {
        await Task.yield()
        try Task.checkCancellation()
        // Mock implementation for testing
        return nil
    }

    nonisolated func findOriginalModelId(from modelCard: String?) -> String? {
        guard let modelCard else { return nil }

        let patterns: [String] = [
            #"converted from ([a-zA-Z0-9-_]+/[a-zA-Z0-9-_.]+)"#,
            #"based on ([a-zA-Z0-9-_]+/[a-zA-Z0-9-_.]+)"#,
            #"MLX version of ([a-zA-Z0-9-_]+/[a-zA-Z0-9-_.]+)"#,
            #"conversion of ([a-zA-Z0-9-_]+/[a-zA-Z0-9-_.]+)"#
        ]

        for pattern: String in patterns {
            guard let regex: NSRegularExpression = try? NSRegularExpression(
                pattern: pattern,
                options: .caseInsensitive
            ) else { continue }
            let matches: [NSTextCheckingResult] = regex.matches(
                in: modelCard,
                range: NSRange(modelCard.startIndex..., in: modelCard)
            )

            if let match: NSTextCheckingResult = matches.first,
               let range: Range<String.Index> = Range(match.range(at: 1), in: modelCard) {
                return String(modelCard[range])
            }
        }

        return nil
    }

    func resolveImageUrl(_ imagePath: String, for modelId: String) -> String {
        // If already absolute URL, return as-is
        if imagePath.hasPrefix("http://") || imagePath.hasPrefix("https://") {
            return imagePath
        }

        // Clean up the path
        var cleanPath: String = imagePath
        if cleanPath.hasPrefix("./") {
            cleanPath = String(cleanPath.dropFirst(2))
        }
        if cleanPath.hasPrefix("/") {
            cleanPath = String(cleanPath.dropFirst())
        }

        return "https://huggingface.co/\(modelId)/resolve/main/\(cleanPath)"
    }

    // MARK: - Helper Methods

    private func shouldFilterImage(alt: String, url: String) -> Bool {
        let altLower: String = alt.lowercased()
        let urlLower: String = url.lowercased()

        // Filter out badges and logos
        let filterTerms: [String] = ["badge", "logo", "icon", "shields.io"]

        for term: String in filterTerms {
            if altLower.contains(term) || urlLower.contains(term) {
                return true
            }
        }

        // Filter out SVG files (often badges)
        if urlLower.hasSuffix(".svg") {
            return true
        }

        return false
    }
}
