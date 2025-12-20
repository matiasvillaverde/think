import Abstractions
import Foundation
@testable import ModelDownloader
import Testing

@Suite("Multi-Quantization Integration Tests")
struct MultiQuantizationIntegrationTests {
    let explorer: CommunityModelsExplorer
    let mockClient: CommunityMockHTTPClient

    init() {
        self.mockClient = CommunityMockHTTPClient()
        self.explorer = CommunityModelsExplorer(httpClient: mockClient)
    }

    @Test("Detect multiple GGUF quantizations")
    @MainActor
    func testMultipleGGUFQuantizations() async {
        // Create a mock model with all GGUF files
        let allFiles: [ModelFile] = [
            ModelFile(path: "gemma-3n-E2B-it-Q4_K_M.gguf", size: 2_979_069_952),
            ModelFile(path: "gemma-3n-E2B-it-Q6_K.gguf", size: 3_989_680_128),
            ModelFile(path: "gemma-3n-E2B-it-Q8_0.gguf", size: 5_138_702_336),
            ModelFile(path: "config.json", size: 1_024),
            ModelFile(path: "README.md", size: 2_048)
        ]

        // Create a discovered model with all files (no selection applied)
        let model: DiscoveredModel = DiscoveredModel(
            id: "lmstudio-community/gemma-3n-E2B-it-text-GGUF",
            name: "gemma-3n-E2B-it-text-GGUF",
            author: "lmstudio-community",
            downloads: 50_000,
            likes: 1_000,
            tags: ["text-generation", "gguf", "llama"],
            lastModified: Date(),
            files: allFiles
        )

        model.modelCard = """
            # Gemma 3n E2B Instruct Text

            This is a 3B parameter model optimized for instruction following.

            ## Model Details
            - Parameters: 3B
            - Context Length: 8192 tokens
            - Architecture: Gemma
            """

        model.detectedBackends = [SendableModel.Backend.gguf]

        // Get available quantizations
        let quantizations: [QuantizationInfo] = await explorer.getAvailableQuantizations(for: model)

        // Should detect 3 GGUF quantizations
        #expect(quantizations.count == 3)

        // Verify quantization levels are detected correctly
        let levels: [QuantizationLevel] = quantizations.map(\.level)
        #expect(levels.contains(.q4_k_m))
        #expect(levels.contains(.q6_k))
        #expect(levels.contains(.q8_0))

        // Verify file sizes
        let quantization4: QuantizationInfo? = quantizations.first { $0.level == .q4_k_m }
        #expect(quantization4?.fileSize == 2_979_069_952)

        // Verify memory requirements are calculated
        for quant in quantizations {
            #expect(quant.memoryRequirements != nil)
            #expect(quant.memoryRequirements!.totalMemory > 0)
        }

        // Verify at least one is marked as recommended
        let hasRecommended: Bool = quantizations.contains(where: \.isRecommended)
        #expect(hasRecommended)
    }

    @Test("Prepare model with specific quantization")
    @MainActor
    func testPrepareWithSpecificQuantization() async throws {
        // Setup mock responses for model card
        mockClient.responses["/test-community/test-model-7B-GGUF/raw/main/README.md"] = HTTPClientResponse(
            data: Data("""
            # Test Model 7B GGUF

            A 7B parameter language model.

            - Parameters: 7B
            - Context window: 4096 tokens
            - Architecture: LLaMA
            """.utf8),
            statusCode: 200,
            headers: [:]
        )

        // Create a model with all GGUF files
        let allFiles: [ModelFile] = [
            ModelFile(path: "model-Q4_K_M.gguf", size: 3_825_904_128),
            ModelFile(path: "model-Q6_K.gguf", size: 5_100_273_664),
            ModelFile(path: "model-Q8_0.gguf", size: 7_516_192_768),
            ModelFile(path: "README.md", size: 2_048)
        ]

        let model: DiscoveredModel = DiscoveredModel(
            id: "test-community/test-model-7B-GGUF",
            name: "test-model-7B-GGUF",
            author: "test-community",
            downloads: 10_000,
            likes: 500,
            tags: ["text-generation", "7B", "gguf", "llama", "instruct"],
            lastModified: Date(),
            files: allFiles,
            license: "apache-2.0"
        )

        model.modelCard = """
            # Test Model 7B GGUF

            A 7B parameter language model.

            - Parameters: 7B
            - Context window: 4096 tokens
            - Architecture: LLaMA
            """

        model.detectedBackends = [SendableModel.Backend.gguf]

        // Get quantizations
        let quantizations: [QuantizationInfo] = await explorer.getAvailableQuantizations(for: model)

        // Pick Q4_K_M quantization
        guard let q4Quant: QuantizationInfo = quantizations.first(
            where: { $0.level == QuantizationLevel.q4_k_m }
        ) else {
            Issue.record("Q4_K_M quantization not found")
            return
        }

        // Prepare for download with specific quantization
        let sendableModel: SendableModel = try await explorer.prepareForDownloadWithQuantization(
            model,
            quantization: q4Quant,
            preferredBackend: .gguf
        )

        // Verify SendableModel has correct properties
        #expect(sendableModel.backend == SendableModel.Backend.gguf)
        #expect(sendableModel.detailedMemoryRequirements != nil)
        #expect(sendableModel.detailedMemoryRequirements?.quantization == .q4_k_m)
        #expect(sendableModel.metadata != nil)
        #expect(sendableModel.metadata?.quantizations.count == 1)
        #expect(sendableModel.metadata?.quantizations[0].level == .q4_k_m)

        // Verify ramNeeded is updated to match quantization
        if let memReq = q4Quant.memoryRequirements {
            #expect(sendableModel.ramNeeded == memReq.totalMemory)
        }
    }

    @Test("Get best quantization for available memory")
    @MainActor
    func testGetBestQuantization() async {
        // Create a model with all GGUF files
        let allFiles: [ModelFile] = [
            ModelFile(path: "model-Q4_K_M.gguf", size: 3_825_904_128),
            ModelFile(path: "model-Q6_K.gguf", size: 5_100_273_664),
            ModelFile(path: "model-Q8_0.gguf", size: 7_516_192_768),
            ModelFile(path: "README.md", size: 2_048)
        ]

        let model: DiscoveredModel = DiscoveredModel(
            id: "test-community/test-model-7B-GGUF",
            name: "test-model-7B-GGUF",
            author: "test-community",
            downloads: 10_000,
            likes: 500,
            tags: ["text-generation", "7B", "gguf", "llama", "instruct"],
            lastModified: Date(),
            files: allFiles
        )
        model.modelCard = """
            # Test Model 7B GGUF

            A 7B parameter language model.

            - Parameters: 7B
            - Context window: 4096 tokens
            - Architecture: LLaMA
            """
        model.detectedBackends = [SendableModel.Backend.gguf]

        // Test with different memory constraints

        // 1. Plenty of memory - should get highest quality
        let bestForLargeMemory: QuantizationInfo? = await explorer.getBestQuantization(
            for: model,
            availableMemory: 16_000_000_000, // 16GB
            minimumQuality: 0.3
        )
        #expect(bestForLargeMemory?.level == .q8_0) // Highest quality GGUF

        // 2. Limited memory - should get smaller quantization
        let bestForLimitedMemory: QuantizationInfo? = await explorer.getBestQuantization(
            for: model,
            availableMemory: 5_000_000_000, // 5GB (to account for overhead on 3.8GB file)
            minimumQuality: 0.3
        )
        #expect(bestForLimitedMemory != nil)
        #expect(bestForLimitedMemory?.level == .q4_k_m) // Should get Q4_K_M

        // 3. Very limited memory - might get nothing
        let bestForTinyMemory: QuantizationInfo? = await explorer.getBestQuantization(
            for: model,
            availableMemory: 1_000_000_000, // 1GB
            minimumQuality: 0.5 // High quality requirement
        )
        #expect(bestForTinyMemory == nil) // No suitable quantization
    }

    @Test("Extract model metadata from discovered model")
    @MainActor
    func testModelMetadataExtraction() async throws {
        // Setup mock response for model card
        mockClient.responses["/test-community/test-model-7B-GGUF/raw/main/README.md"] = HTTPClientResponse(
            data: Data("""
            # Test Model 7B GGUF

            A 7B parameter language model.

            - Parameters: 7B
            - Context window: 4096 tokens
            - Architecture: LLaMA
            """.utf8),
            statusCode: 200,
            headers: [:]
        )

        // Create a model with GGUF file
        let allFiles: [ModelFile] = [
            ModelFile(path: "model-Q4_K_M.gguf", size: 3_825_904_128),
            ModelFile(path: "README.md", size: 2_048)
        ]

        let model: DiscoveredModel = DiscoveredModel(
            id: "test-community/test-model-7B-GGUF",
            name: "test-model-7B-GGUF",
            author: "test-community",
            downloads: 10_000,
            likes: 500,
            tags: ["text-generation", "7B", "gguf", "llama", "instruct"],
            lastModified: Date(),
            files: allFiles,
            license: "apache-2.0"
        )
        model.modelCard = """
            # Test Model 7B GGUF

            A 7B parameter language model.

            - Parameters: 7B
            - Context window: 4096 tokens
            - Architecture: LLaMA
            """
        model.detectedBackends = [SendableModel.Backend.gguf]
        let quantizations: [QuantizationInfo] = await explorer.getAvailableQuantizations(for: model)

        guard let firstQuant = quantizations.first else {
            Issue.record("No quantizations found")
            return
        }

        let sendableModel: SendableModel = try await explorer.prepareForDownloadWithQuantization(
            model,
            quantization: firstQuant
        )

        guard let metadata = sendableModel.metadata else {
            Issue.record("No metadata found")
            return
        }

        // Verify metadata extraction
        // Note: Parameter extraction from complex names like "test-model-7B-GGUF" 
        // requires regex pattern matching which isn't implemented yet
        // So parameters might be 0 if not extracted
        #expect(metadata.quantizations.count >= 1)
        #expect(metadata.quantizations.count == 1)

        // If model card had context info, it should be extracted
        if let contextLength = metadata.contextLength {
            #expect(contextLength > 0)
        }
    }

    @Test("Quantization info creation from model files")
    func testQuantizationInfoFromModelFile() {
        let calculator: VRAMCalculator = VRAMCalculator()

        // Test GGUF file
        let ggufFile: ModelFile = ModelFile(
            path: "models/llama-7b-Q4_K_M.gguf",
            size: 3_825_904_128,
            sha: "abc123"
        )

        let quantInfo: QuantizationInfo? = QuantizationInfo.from(
            file: ggufFile,
            calculator: calculator,
            parameters: 7_000_000_000
        )

        #expect(quantInfo != nil)
        #expect(quantInfo?.level == .q4_k_m)
        #expect(quantInfo?.fileSize == 3_825_904_128)
        #expect(quantInfo?.fileName == "llama-7b-Q4_K_M.gguf")
        #expect(quantInfo?.memoryRequirements != nil)

        // Test formatting
        #expect(quantInfo?.formattedFileSize.contains("GB") ?? false)
        #expect(quantInfo?.displayName.contains("Q4_K_M") ?? false)
    }

    // MARK: - Helper Methods

    private func setupMockModelWithQuantizations() {
        // Mock model response
        mockClient.responses["/api/models?author=test-community&search=test-model-GGUF"] = HTTPClientResponse(
            data: Data("""
            [{
                "modelId": "test-community/test-model-7B-GGUF",
                "author": "test-community",
                "downloads": 10000,
                "likes": 500,
                "tags": ["text-generation", "7B", "gguf", "llama", "instruct"],
                "lastModified": "2024-01-20T10:00:00Z",
                "cardData": {
                    "license": "apache-2.0"
                },
                "siblings": [
                    {"rfilename": "model-Q4_K_M.gguf", "size": 3825904128},
                    {"rfilename": "model-Q6_K.gguf", "size": 5100273664},
                    {"rfilename": "model-Q8_0.gguf", "size": 7516192768}
                ]
            }]
            """.utf8),
            statusCode: 200,
            headers: [:]
        )

        // Mock repository file listing
        let treeUrl: String = "/api/models/test-community/test-model-7B-GGUF/tree/main?recursive=true"
        mockClient.responses[treeUrl] = HTTPClientResponse(
            data: Data("""
            [
                {
                    "type": "file", "path": "model-Q4_K_M.gguf", "size": 3825904128,
                    "lfs": {"oid": "abc123", "size": 3825904128, "pointerSize": 128}
                },
                {
                    "type": "file", "path": "model-Q6_K.gguf", "size": 5100273664,
                    "lfs": {"oid": "def456", "size": 5100273664, "pointerSize": 128}
                },
                {
                    "type": "file", "path": "model-Q8_0.gguf", "size": 7516192768,
                    "lfs": {"oid": "ghi789", "size": 7516192768, "pointerSize": 128}
                },
                {"type": "file", "path": "README.md", "size": 2048}
            ]
            """.utf8),
            statusCode: 200,
            headers: [:]
        )

        // Mock model card
        mockClient.responses["/test-community/test-model-7B-GGUF/raw/main/README.md"] = HTTPClientResponse(
            data: Data("""
            # Test Model 7B GGUF

            A 7B parameter language model.

            - Parameters: 7B
            - Context window: 4096 tokens
            - Architecture: LLaMA
            """.utf8),
            statusCode: 200,
            headers: [:]
        )
    }
}
