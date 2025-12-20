import Abstractions
import Foundation
@testable import ModelDownloader
import Testing

@Suite("QuantizationDetector Tests")
struct QuantizationDetectorTests {
    let detector: QuantizationDetector = QuantizationDetector()

    @Test("Detect GGUF quantizations from files")
    func testDetectGGUFQuantizations() {
        let files: [ModelFile] = [
            ModelFile(path: "model-Q2_K.gguf", size: 1_500_000_000),
            ModelFile(path: "model-Q4_K_M.gguf", size: 3_000_000_000),
            ModelFile(path: "model-Q5_K_S.gguf", size: 3_750_000_000),
            ModelFile(path: "model-Q6_K.gguf", size: 4_500_000_000),
            ModelFile(path: "model-Q8_0.gguf", size: 6_000_000_000),
            ModelFile(path: "config.json", size: 1_024),
            ModelFile(path: "README.md", size: 2_048)
        ]

        let quantizations: [QuantizationInfo] = detector.detectGGUFQuantizations(in: files)

        // Should detect 5 GGUF quantizations
        #expect(quantizations.count == 5)

        // Verify correct levels detected
        let levels: Set<QuantizationLevel> = Set(quantizations.map(\.level))
        #expect(levels.contains(.q2_k))
        #expect(levels.contains(.q4_k_m))
        #expect(levels.contains(.q5_k_s))
        #expect(levels.contains(.q6_k))
        #expect(levels.contains(.q8_0))

        // Verify they're sorted by quality (highest first)
        let sortedByQuality: [QuantizationInfo] = quantizations.sorted(by: QuantizationInfo.byQuality)
        #expect(sortedByQuality.first?.level == .q8_0)
        #expect(sortedByQuality.last?.level == .q2_k)
    }

    @Test("Detect quantizations with parameter extraction")
    @MainActor
    func testDetectWithParameterExtraction() {
        // Create a model with parameters in the name
        let model: DiscoveredModel = DiscoveredModel(
            id: "test-org/Llama-7B-Instruct-GGUF",
            name: "Llama-7B-Instruct-GGUF",
            author: "test-org",
            downloads: 1_000,
            likes: 100,
            tags: ["7B", "text-generation"],
            lastModified: Date(),
            files: [
                ModelFile(path: "llama-7b-instruct-Q4_K_M.gguf", size: 3_825_904_128),
                ModelFile(path: "llama-7b-instruct-Q8_0.gguf", size: 7_516_192_768)
            ]
        )

        let quantizations: [QuantizationInfo] = detector.detectQuantizations(in: model)

        #expect(quantizations.count == 2)

        // Should have memory requirements calculated with 7B parameters
        for quant: QuantizationInfo in quantizations {
            #expect(quant.memoryRequirements != nil)

            // Verify memory is reasonable for 7B model
            if let memReq: MemoryRequirements = quant.memoryRequirements {
                if quant.level == .q4_k_m {
                    // ~3.5GB base + overhead
                    #expect(memReq.totalMemory > 3_000_000_000)
                    #expect(memReq.totalMemory < 6_000_000_000)
                } else if quant.level == .q8_0 {
                    // ~7GB base + overhead
                    #expect(memReq.totalMemory > 7_000_000_000)
                    #expect(memReq.totalMemory < 10_000_000_000)
                }
            }
        }
    }

    @Test("Extract parameters from model card")
    @MainActor
    func testParameterExtractionFromModelCard() {
        let modelCardVariants: [String] = [
            """
            # Model Card
            This is a 13B parameter model trained on...
            """,
            """
            ## Model Details
            - Parameters: 70B
            - Training data: ...
            """,
            """
            Model size: 1.5B parameters
            Context: 4k tokens
            """,
            """
            This model has 8x7B parameters (Mixture of Experts)
            """
        ]

        let expectedParams: [UInt64?] = [
            13_000_000_000,
            70_000_000_000,
            1_500_000_000,
            56_000_000_000 // 8x7B
        ]

        for (card, expected) in zip(modelCardVariants, expectedParams) {
            let model: DiscoveredModel = DiscoveredModel(
                id: "test/model",
                name: "model",
                author: "test",
                downloads: 0,
                likes: 0,
                tags: [],
                lastModified: Date(),
                files: [ModelFile(path: "model.gguf", size: 1_000)]
            )
            model.modelCard = card

            let quantizations: [QuantizationInfo] = detector.detectQuantizations(in: model)

            if expected != nil, !quantizations.isEmpty {
                // Check if parameters were extracted correctly
                let memReq: MemoryRequirements? = quantizations[0].memoryRequirements
                #expect(memReq != nil)
                // Parameters should influence memory calculation
            }
        }
    }

    @Test("Recommended quantization marking")
    @MainActor
    func testRecommendedQuantizationMarking() {
        let files: [ModelFile] = [
            ModelFile(path: "model-Q2_K.gguf", size: 1_500_000_000),
            ModelFile(path: "model-Q4_K_M.gguf", size: 3_000_000_000), // Should be recommended
            ModelFile(path: "model-Q5_K_M.gguf", size: 3_750_000_000), // Should be recommended
            ModelFile(path: "model-Q8_0.gguf", size: 6_000_000_000)
        ]

        let model: DiscoveredModel = DiscoveredModel(
            id: "test/model",
            name: "model",
            author: "test",
            downloads: 0,
            likes: 0,
            tags: [],
            lastModified: Date(),
            files: files
        )

        let quantizations: [QuantizationInfo] = detector.detectQuantizations(in: model)

        // Should have at least one recommended
        let recommendedCount: Int = quantizations.filter(\.isRecommended).count
        #expect(recommendedCount >= 1)

        // Q4_K_M or Q5_K_M should be recommended
        let recommendedLevels: [QuantizationLevel] = quantizations
            .filter(\.isRecommended)
            .map(\.level)

        let hasExpectedRecommendation: Bool = recommendedLevels.contains(.q4_k_m) ||
                                       recommendedLevels.contains(.q5_k_m)
        #expect(hasExpectedRecommendation)
    }

    @Test("Group quantizations by backend")
    @MainActor
    func testGroupByBackend() {
        let quantizations: [QuantizationInfo] = [
            QuantizationInfo(level: .q4_k_m, fileSize: 3_000_000_000, fileName: "model-Q4.gguf"),
            QuantizationInfo(level: .q6_k, fileSize: 4_500_000_000, fileName: "model-Q6.gguf"),
            QuantizationInfo(level: .fp16, fileSize: 14_000_000_000, fileName: "model.safetensors"),
            QuantizationInfo(level: .fp32, fileSize: 28_000_000_000, fileName: "model.mlpackage")
        ]

        let model: DiscoveredModel = DiscoveredModel(
            id: "test/model",
            name: "model",
            author: "test",
            downloads: 0,
            likes: 0,
            tags: [],
            lastModified: Date(),
            files: []
        )

        let grouped: [SendableModel.Backend: [QuantizationInfo]] = detector.groupByBackend(quantizations, for: model)

        // Should have 3 backend groups
        #expect(grouped.count == 3)
        #expect(grouped[.gguf]?.count == 2)
        #expect(grouped[.mlx]?.count == 1)
        #expect(grouped[.coreml]?.count == 1)
    }

    @Test("Fuzzing test for malformed filenames")
    @MainActor
    func testMalformedFilenameFuzzing() {
        // Test various edge cases and malformed filenames
        let edgeCaseFiles: [ModelFile] = [
            // Multiple quantization patterns
            ModelFile(path: "model-Q4_K_M-v2-GGUF.bin", size: 3_000_000_000),
            ModelFile(path: "Q4_K_M-model-Q8_0.gguf", size: 3_000_000_000),

            // Mixed case variations
            ModelFile(path: "model-q4_k_m.GGUF", size: 3_000_000_000),
            ModelFile(path: "MODEL-Q4_k_M.GgUf", size: 3_000_000_000),

            // Special characters
            ModelFile(path: "model@Q4_K_M#.gguf", size: 3_000_000_000),
            ModelFile(path: "model Q4_K_M .gguf", size: 3_000_000_000),
            ModelFile(path: "model_Q4_K_M_.gguf", size: 3_000_000_000),

            // Missing extensions
            ModelFile(path: "model-Q4_K_M", size: 3_000_000_000),
            ModelFile(path: "Q4_K_M", size: 3_000_000_000),

            // Very long filenames
            ModelFile(path: String(repeating: "a", count: 200) + "-Q4_K_M.gguf", size: 3_000_000_000),

            // Empty and minimal names
            ModelFile(path: "", size: 3_000_000_000),
            ModelFile(path: ".gguf", size: 3_000_000_000),
            ModelFile(path: "Q.gguf", size: 3_000_000_000),

            // Unicode characters
            ModelFile(path: "模型-Q4_K_M.gguf", size: 3_000_000_000),
            ModelFile(path: "model-Q4_K_M-🤖.gguf", size: 3_000_000_000),

            // Multiple dots and extensions
            ModelFile(path: "model.Q4_K_M.tar.gz.gguf", size: 3_000_000_000),
            ModelFile(path: "model..Q4_K_M..gguf", size: 3_000_000_000),

            // Numeric variations
            ModelFile(path: "model-Q444_K_M.gguf", size: 3_000_000_000),
            ModelFile(path: "model-Q4.5_K_M.gguf", size: 3_000_000_000),

            // Wrong format indicators
            ModelFile(path: "model-FP16.gguf", size: 3_000_000_000),
            ModelFile(path: "model-INT8.gguf", size: 3_000_000_000)
        ]

        // Test that detector doesn't crash on any input
        for file: ModelFile in edgeCaseFiles {
            let quantizations: [QuantizationInfo] = detector.detectGGUFQuantizations(in: [file])

            // Should either detect a valid quantization or return empty
            #expect(quantizations.count <= 1)

            // If detected, should have valid properties
            if let quant: QuantizationInfo = quantizations.first {
                #expect(quant.fileSize > 0)
                #expect(quant.level.bitsPerParameter > 0)
                #expect(quant.fileName != nil)
            }
        }
    }

    @Test("Quantization detection with ambiguous patterns")
    func testAmbiguousPatternDetection() {
        let ambiguousFiles: [ModelFile] = [
            // Files that could match multiple patterns
            ModelFile(path: "q4_0_q5_1_model.gguf", size: 3_000_000_000),
            ModelFile(path: "model_fp16_int8_mixed.gguf", size: 3_000_000_000),
            ModelFile(path: "Q4_K_S_Q4_K_M_variant.gguf", size: 3_000_000_000)
        ]

        for file: ModelFile in ambiguousFiles {
            let quantizations: [QuantizationInfo] = detector.detectGGUFQuantizations(in: [file])

            // Should detect at most one quantization per file
            #expect(quantizations.count <= 1)

            // Should prioritize the first valid match
            if file.path.contains("q4_0_q5_1") {
                #expect(quantizations.first?.level == .q4_0 || quantizations.isEmpty)
            }
        }
    }
}
