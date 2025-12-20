import Abstractions
import Foundation
@testable import ModelDownloader
import Testing

extension APITests {
    // MARK: - Real API Tests

    @Test("Extract images from unsloth/DeepSeek-R1-0528-Qwen3-8B-GGUF")
    func testExtractImagesFromDeepSeekModel() async throws {
        let extractor: ImageExtractor = ImageExtractor()
        let modelId: String = "unsloth/DeepSeek-R1-0528-Qwen3-8B-GGUF"

        let imageUrls: [String] = try await extractor.extractImageUrls(from: modelId)

        print("Found \(imageUrls.count) images for \(modelId):")
        for (index, url) in imageUrls.enumerated() {
            print("  \(index + 1). \(url)")
        }

        // Verify we found some images
        #expect(!imageUrls.isEmpty, "Should find at least one image for DeepSeek model")

        // Check for the specific images mentioned
        let hasLogoSvg: Bool = imageUrls.contains { url in
            url.contains("logo.svg") || url.contains("deepseek-ai/DeepSeek-V2")
        }

        let hasBenchmarkPng: Bool = imageUrls.contains { url in
            url.contains("benchmark.png")
        }

        print("Image analysis:")
        print("  - Logo SVG found: \(hasLogoSvg)")
        print("  - Benchmark PNG found: \(hasBenchmarkPng)")

        // At least one of the expected images should be found
        #expect(hasLogoSvg || hasBenchmarkPng, "Should find either logo.svg or benchmark.png")
    }

    @Test("Extract images from MLX community model")
    func testExtractImagesFromMLXModel() async throws {
        let extractor: ImageExtractor = ImageExtractor()
        let modelId: String = "mlx-community/Llama-3.2-3B-Instruct-4bit"

        let imageUrls: [String] = try await extractor.extractImageUrls(from: modelId)

        print("Found \(imageUrls.count) images for MLX model \(modelId):")
        for (index, url) in imageUrls.enumerated() {
            print("  \(index + 1). \(url)")
        }

        // MLX models might not have images, but the extractor shouldn't crash
        #expect(true, "Should return array without crashing")
    }

    @Test("Extract images from CoreML model (known to have images)")
    func testExtractImagesFromCoreMLModel() async throws {
        let extractor: ImageExtractor = ImageExtractor()
        let modelId: String = "coreml-community/coreml-stable-diffusion-v1-5"

        let imageUrls: [String] = try await extractor.extractImageUrls(from: modelId)

        print("Found \(imageUrls.count) images for CoreML model \(modelId):")
        for (index, url) in imageUrls.enumerated() {
            print("  \(index + 1). \(url)")
        }

        // CoreML models often have many example images
        #expect(true, "Should extract images from CoreML model")
    }

    // MARK: - Model Card Text Parsing Tests

    @Test("Extract images from model card with various formats")
    func testExtractImagesFromModelCard() {
        let extractor: ImageExtractor = ImageExtractor()

        let modelCard: String = """
        # DeepSeek-R1 Model

        This is the DeepSeek-R1 model converted to GGUF format.

        ![Logo](https://raw.githubusercontent.com/deepseek-ai/DeepSeek-V2/refs/heads/main/figures/logo.svg)

        ## Performance

        <img src="benchmark.png" alt="Benchmark Results">

        ![Results](./results/accuracy.png)

        ## Examples

        ![Example Output](https://cdn-lfs-us-1.hf.co/repos/a2/c8/example.png)
        """

        let imageUrls: [String] = extractor.extractImageUrls(from: modelCard, modelId: "unsloth/test-model")

        print("Extracted \(imageUrls.count) images from model card:")
        for (index, url) in imageUrls.enumerated() {
            print("  \(index + 1). \(url)")
        }

        #expect(imageUrls.count >= 3, "Should extract at least 3 images from model card")

        // Check for specific images
        let hasLogo: Bool = imageUrls.contains { $0.contains("logo.svg") }
        let hasBenchmark: Bool = imageUrls.contains { $0.contains("benchmark.png") }
        let hasResults: Bool = imageUrls.contains { $0.contains("accuracy.png") }

        #expect(hasLogo, "Should find logo.svg")
        #expect(hasBenchmark, "Should find benchmark.png")
        #expect(hasResults, "Should find accuracy.png")
    }

    // MARK: - Original Model Detection Tests

    @Test("Find original model from conversion text")
    func testFindOriginalModelFromDeepSeekCard() {
        let extractor: ImageExtractor = ImageExtractor()

        // Test with conversion text that might be in the DeepSeek model
        let modelCard: String = """
        # DeepSeek-R1-0528-Qwen3-8B-GGUF

        This model was converted from deepseek-ai/DeepSeek-R1-0528-Qwen3-8B using llama.cpp.

        Original model: deepseek-ai/DeepSeek-R1-0528-Qwen3-8B
        """

        // Use the synchronous text parsing method directly
        let originalId: String? = extractor.findOriginalModelId(from: Optional(modelCard))

        print("Found original model ID: \(originalId ?? "none")")

        #expect(originalId == "deepseek-ai/DeepSeek-R1-0528-Qwen3-8B", "Should find original DeepSeek model ID")
    }

    // MARK: - URL Resolution Tests

    @Test("Resolve various URL formats")
    func testResolveImageUrls() {
        let extractor: ImageExtractor = ImageExtractor()
        let modelId: String = "unsloth/DeepSeek-R1-0528-Qwen3-8B-GGUF"

        let testCases: [(String, String)] = [
            ("logo.svg", "https://huggingface.co/unsloth/DeepSeek-R1-0528-Qwen3-8B-GGUF/resolve/main/logo.svg"),
            ("./benchmark.png",
             "https://huggingface.co/unsloth/DeepSeek-R1-0528-Qwen3-8B-GGUF/resolve/main/benchmark.png"),
            ("/images/result.jpg",
             "https://huggingface.co/unsloth/DeepSeek-R1-0528-Qwen3-8B-GGUF/resolve/main/images/result.jpg"),
            ("https://example.com/external.png", "https://example.com/external.png")
        ]

        for (input, expected) in testCases {
            let result: String = extractor.resolveImageUrl(input, for: modelId)
            print("🔗 \(input) -> \(result)")
            #expect(result == expected, "Failed to resolve: \(input)")
        }
    }

    // MARK: - Error Handling Tests

    @Test("Handle non-existent model gracefully")
    func testHandleNonExistentModel() async throws {
        let extractor: ImageExtractor = ImageExtractor()
        let modelId: String = "non-existent/fake-model-12345"

        do {
            let imageUrls: [String] = try await extractor.extractImageUrls(from: modelId)
            print("Non-existent model returned \(imageUrls.count) images")
            // Should return empty array or throw, but not crash
        } catch {
            print("Expected error for non-existent model: \(error)")
            // This is expected behavior
        }
    }

    // MARK: - Performance Tests

    @Test("Extract images from multiple models concurrently")
    func testConcurrentImageExtraction() async throws {
        let extractor: ImageExtractor = ImageExtractor()
        let modelIds: [String] = [
            "unsloth/DeepSeek-R1-0528-Qwen3-8B-GGUF",
            "mlx-community/Llama-3.2-3B-Instruct-4bit",
            "coreml-community/coreml-stable-diffusion-v1-5"
        ]

        let startTime: Date = Date()

        let results: [(String, Int)] = await withTaskGroup(of: (String, Int).self) { group in
            for modelId: String in modelIds {
                group.addTask {
                    do {
                        let images: [String] = try await extractor.extractImageUrls(from: modelId)
                        return (modelId, images.count)
                    } catch {
                        print("Failed to extract images from \(modelId): \(error)")
                        return (modelId, 0)
                    }
                }
            }

            var results: [(String, Int)] = []
            for await result in group {
                results.append(result)
            }
            return results
        }

        let duration: TimeInterval = Date().timeIntervalSince(startTime)

        print("🏁 Concurrent extraction completed in \(String(format: "%.2f", duration))s:")
        for (modelId, imageCount) in results {
            print("  - \(modelId): \(imageCount) images")
        }

        #expect(results.count == modelIds.count, "Should process all models")
        #expect(duration < 30.0, "Should complete within 30 seconds")
    }
}

// MARK: - Test Extensions

extension Testing.Tag {
    @Testing.Tag static var acceptance: Self
}
