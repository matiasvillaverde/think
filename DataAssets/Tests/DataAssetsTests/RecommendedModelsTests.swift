import Testing
@testable import DataAssets

@Suite("RecommendedModels Tests")
struct RecommendedModelsTests {
    // MARK: - Memory Tier Tests

    @Test("Should return memory tier for exact memory values")
    func testExactMemoryTiers() {
        #expect(RecommendedModels.getMemoryTier(for: 4 * RecommendedModels.MemorySize.GB) == .fourGB)
        #expect(RecommendedModels.getMemoryTier(for: 8 * RecommendedModels.MemorySize.GB) == .eightGB)
        #expect(RecommendedModels.getMemoryTier(for: 16 * RecommendedModels.MemorySize.GB) == .sixteenGB)
        #expect(RecommendedModels.getMemoryTier(for: 32 * RecommendedModels.MemorySize.GB) == .thirtyTwoGB)
        #expect(RecommendedModels.getMemoryTier(for: 64 * RecommendedModels.MemorySize.GB) == .sixtyFourGB)
        #expect(RecommendedModels.getMemoryTier(for: 128 * RecommendedModels.MemorySize.GB) == .oneTwentyEightGBPlus)
    }

    @Test("Should handle memory values with tolerance")
    func testMemoryTiersWithTolerance() {
        // Test values slightly below tier thresholds
        #expect(RecommendedModels.getMemoryTier(for: UInt64(3.8 * Double(RecommendedModels.MemorySize.GB))) == .fourGB)
        #expect(RecommendedModels.getMemoryTier(for: UInt64(7.8 * Double(RecommendedModels.MemorySize.GB))) == .eightGB)
        #expect(RecommendedModels.getMemoryTier(for: UInt64(15.5 * Double(RecommendedModels.MemorySize.GB))) == .sixteenGB)
        #expect(RecommendedModels.getMemoryTier(for: UInt64(31.2 * Double(RecommendedModels.MemorySize.GB))) == .thirtyTwoGB)
        #expect(RecommendedModels.getMemoryTier(for: UInt64(62.5 * Double(RecommendedModels.MemorySize.GB))) == .sixtyFourGB)
    }

    @Test("Should handle edge cases for memory tiers")
    func testMemoryTierEdgeCases() {
        // Very low memory should still get 4GB tier
        #expect(RecommendedModels.getMemoryTier(for: 2 * RecommendedModels.MemorySize.GB) == .fourGB)

        // Values between tiers should round to appropriate tier
        #expect(RecommendedModels.getMemoryTier(for: 6 * RecommendedModels.MemorySize.GB) == .eightGB)
        #expect(RecommendedModels.getMemoryTier(for: 12 * RecommendedModels.MemorySize.GB) == .sixteenGB)
        #expect(RecommendedModels.getMemoryTier(for: 24 * RecommendedModels.MemorySize.GB) == .thirtyTwoGB)
        #expect(RecommendedModels.getMemoryTier(for: 48 * RecommendedModels.MemorySize.GB) == .sixtyFourGB)

        // Very high memory
        #expect(RecommendedModels.getMemoryTier(for: 256 * RecommendedModels.MemorySize.GB) == .oneTwentyEightGBPlus)
    }

    // MARK: - Model Filtering Tests

    @Test("Should return appropriate models for 4GB devices")
    func testModelsForFourGBDevices() {
        let models = RecommendedModels.getLanguageModels(forMemory: 4 * RecommendedModels.MemorySize.GB)

        // Should include 4GB models
        #expect(models.contains("mlx-community/gemma-3-1b-it-qat-4bit"))
        #expect(models.contains("mlx-community/Qwen3-0.6B-4bit"))
        #expect(models.contains("mlx-community/Qwen3-1.7B-4bit"))
        #expect(models.contains("mlx-community/DeepSeek-R1-Distill-Qwen-1.5B-4bit"))

        // Should NOT include 8GB or higher models
        #expect(!models.contains("mlx-community/gemma-3-4b-it-qat-4bit"))
        #expect(!models.contains("mlx-community/Qwen3-4B-8bit"))
        #expect(!models.contains("mlx-community/gemma-3n-E4B-it-4bit"))
    }

    @Test("Should return appropriate models for 8GB devices")
    func testModelsForEightGBDevices() {
        let models = RecommendedModels.getLanguageModels(forMemory: 8 * RecommendedModels.MemorySize.GB)

        // Should include both 4GB and 8GB models
        #expect(models.contains("mlx-community/gemma-3-1b-it-qat-4bit")) // 4GB model
        #expect(models.contains("mlx-community/Qwen3-1.7B-4bit")) // 4GB model
        #expect(models.contains("mlx-community/gemma-3-4b-it-qat-4bit")) // 8GB model
        #expect(models.contains("mlx-community/Qwen3-4B-8bit")) // 8GB model

        // Should NOT include 16GB or higher models
        #expect(!models.contains("mlx-community/gemma-3n-E4B-it-4bit"))
        #expect(!models.contains("mlx-community/Meta-Llama-3.1-8B-Instruct-4bit"))
    }

    @Test("Should return appropriate models for 16GB devices")
    func testModelsForSixteenGBDevices() {
        let models = RecommendedModels.getLanguageModels(forMemory: 16 * RecommendedModels.MemorySize.GB)

        // Should include 4GB, 8GB, and 16GB models
        #expect(models.contains("mlx-community/gemma-3-1b-it-qat-4bit")) // 4GB
        #expect(models.contains("mlx-community/gemma-3-4b-it-qat-4bit")) // 8GB
        #expect(models.contains("mlx-community/gemma-3n-E4B-it-4bit")) // 16GB
        #expect(models.contains("mlx-community/Meta-Llama-3.1-8B-Instruct-4bit")) // 16GB

        // Should NOT include 32GB or higher models
        #expect(!models.contains("mlx-community/gemma-3-12b-it-qat-4bit"))
        #expect(!models.contains("mlx-community/Qwen3-30B-A3B-4bit"))
    }

    @Test("Should handle devices with non-exact memory values")
    func testModelsForNonExactMemory() {
        // 7.8GB device should get 8GB tier models
        let models7_8GB = RecommendedModels.getLanguageModels(forMemory: UInt64(7.8 * Double(RecommendedModels.MemorySize.GB)))
        #expect(models7_8GB.contains("mlx-community/gemma-3-4b-it-qat-4bit")) // 8GB model

        // 15.5GB device should get 16GB tier models
        let models15_5GB = RecommendedModels.getLanguageModels(forMemory: UInt64(15.5 * Double(RecommendedModels.MemorySize.GB)))
        #expect(models15_5GB.contains("mlx-community/gemma-3n-E4B-it-4bit")) // 16GB model
    }

    // MARK: - Tier-Exclusive Model Tests

    @Test("8GB devices should get ONLY 8GB tier models plus always-include models")
    func testEightGBDevicesGetOnlyTheirTierModels() {
        let models = RecommendedModels.getLanguageModelsForExactTier(forMemory: 8 * RecommendedModels.MemorySize.GB)

        // Should include 8GB tier models
        #expect(models.contains("mlx-community/Qwen3-4B-8bit"))
        #expect(models.contains("mlx-community/gemma-3-4b-it-qat-4bit"))

        // Should NOT include 4GB tier models (except always-include)
        #expect(!models.contains("mlx-community/gemma-3-1b-it-qat-4bit"))
        #expect(!models.contains("mlx-community/Llama-3.2-1B-Instruct-4bit"))

        // Should ALWAYS include these models
        #expect(models.contains("mlx-community/Qwen3-1.7B-4bit"))
        #expect(models.contains("lmstudio-community/Qwen3-4B-Instruct-2507-GGUF"))

        // Should have exactly 12 models (8 from 8GB tier + 4 always-include)
        #expect(models.count == 12)
    }

    @Test("16GB devices should get ONLY 16GB tier models plus always-include models")
    func testSixteenGBDevicesGetOnlyTheirTierModels() {
        let models = RecommendedModels.getLanguageModelsForExactTier(forMemory: 16 * RecommendedModels.MemorySize.GB)

        // Should include 16GB tier models
        #expect(models.contains("mlx-community/Qwen3-14B-4bit"))
        #expect(models.contains("mlx-community/Meta-Llama-3.1-8B-Instruct-4bit"))

        // Should NOT include lower tier models (except always-include)
        #expect(!models.contains("mlx-community/Qwen3-4B-8bit")) // 8GB tier
        #expect(!models.contains("mlx-community/gemma-3-1b-it-qat-4bit")) // 4GB tier

        // Should ALWAYS include these models
        #expect(models.contains("mlx-community/Qwen3-1.7B-4bit"))
        #expect(models.contains("lmstudio-community/Qwen3-4B-Instruct-2507-GGUF"))

        // Should have exactly 12 models (8 from 16GB tier + 4 always-include)
        #expect(models.count == 12)
    }

    @Test("Always-include models appear in all tiers")
    func testAlwaysIncludeModelsInAllTiers() {
        let tiers: [RecommendedModels.MemoryTier] = [.fourGB, .eightGB, .sixteenGB, .thirtyTwoGB]

        for tier in tiers {
            let models = RecommendedModels.getLanguageModelsForExactTier(forMemory: tier.threshold)
            #expect(models.contains("mlx-community/Qwen3-1.7B-4bit"))
            #expect(models.contains("lmstudio-community/Qwen3-4B-Instruct-2507-GGUF"))
        }
    }

    @Test("iPhone 8GB should get both 4GB and 8GB tier models")
    func testIPhone8GBMemoryTier() {
        // iPhone 8GB typically reports ~7.48GB total memory (8028684288 bytes)
        let iPhone8GBMemory: UInt64 = 8028684288

        let tier = RecommendedModels.getMemoryTier(for: iPhone8GBMemory)
        #expect(tier == .eightGB)

        let models = RecommendedModels.getLanguageModels(forMemory: iPhone8GBMemory)

        // Should get exactly 17 models (9 from 4GB tier + 8 from 8GB tier)
        #expect(models.count == 17)

        // Verify it includes models from both tiers
        #expect(models.contains("mlx-community/gemma-3-1b-it-qat-4bit")) // 4GB tier
        #expect(models.contains("mlx-community/Llama-3.2-1B-Instruct-4bit")) // 4GB tier
        #expect(models.contains("mlx-community/gemma-3-4b-it-qat-4bit")) // 8GB tier
        #expect(models.contains("mlx-community/Llama-3.2-3B-Instruct-4bit")) // 8GB tier

        // Should NOT include 16GB tier models
        #expect(!models.contains("mlx-community/gemma-3n-E4B-it-4bit")) // 16GB tier
    }

    @Test("Should return all models for very high memory devices")
    func testModelsForHighMemoryDevices() {
        let models = RecommendedModels.getLanguageModels(forMemory: 256 * RecommendedModels.MemorySize.GB)

        // Should include all models
        #expect(models.count == RecommendedModels.defaultLanguageModels.count)
    }

    // MARK: - Memory Tier Enum Tests

    @Test("Memory tier should include lower tiers")
    func testMemoryTierInclusion() {
        #expect(RecommendedModels.MemoryTier.fourGB.includesModelsFromTier(.fourGB))
        #expect(!RecommendedModels.MemoryTier.fourGB.includesModelsFromTier(.eightGB))

        #expect(RecommendedModels.MemoryTier.eightGB.includesModelsFromTier(.fourGB))
        #expect(RecommendedModels.MemoryTier.eightGB.includesModelsFromTier(.eightGB))
        #expect(!RecommendedModels.MemoryTier.eightGB.includesModelsFromTier(.sixteenGB))

        #expect(RecommendedModels.MemoryTier.sixteenGB.includesModelsFromTier(.fourGB))
        #expect(RecommendedModels.MemoryTier.sixteenGB.includesModelsFromTier(.eightGB))
        #expect(RecommendedModels.MemoryTier.sixteenGB.includesModelsFromTier(.sixteenGB))
        #expect(!RecommendedModels.MemoryTier.sixteenGB.includesModelsFromTier(.thirtyTwoGB))
    }

    // MARK: - Recommendation Type Tests

    @Test("Should return correct recommendation type for always-include models")
    func testRecommendationTypeForAlwaysIncludeModels() {
        #expect(RecommendedModels.getRecommendationType(for: "mlx-community/Qwen3-1.7B-4bit") == .fast)
        #expect(RecommendedModels.isRecommendedForFastTasks("mlx-community/Qwen3-1.7B-4bit"))
        #expect(!RecommendedModels.isRecommendedForComplexTasks("mlx-community/Qwen3-1.7B-4bit"))
    }

    @Test("Should return nil for non-recommended models")
    func testRecommendationTypeForNonRecommendedModels() {
        let nonRecommendedModel = "mlx-community/some-random-model"
        #expect(RecommendedModels.getRecommendationType(for: nonRecommendedModel) == nil)
        #expect(!RecommendedModels.isRecommendedForFastTasks(nonRecommendedModel))
        #expect(!RecommendedModels.isRecommendedForComplexTasks(nonRecommendedModel))
    }

    @Test("RecommendationType should have correct display names")
    func testRecommendationTypeDisplayNames() {
        #expect(RecommendedModels.RecommendationType.fast.displayName == "Recommended Fast")
        #expect(RecommendedModels.RecommendationType.complexTasks.displayName == "Recommended for Complex Tasks")
    }

    @Test("RecommendationType should have correct raw values")
    func testRecommendationTypeRawValues() {
        #expect(RecommendedModels.RecommendationType.fast.rawValue == "recommended_fast")
        #expect(RecommendedModels.RecommendationType.complexTasks.rawValue == "recommended_complex_tasks")
    }

    // MARK: - Remote Models Tests

    @Test("Free remote models should have correct format")
    func testFreeRemoteModelsFormat() {
        // All free remote models should start with "openrouter:" prefix
        for model in RecommendedModels.freeRemoteModels {
            #expect(model.hasPrefix("openrouter:"), "Model \(model) should have openrouter prefix")
        }

        // Should have at least 5 free models
        #expect(RecommendedModels.freeRemoteModels.count >= 5)
    }

    @Test("Premium remote models should have correct format")
    func testPremiumRemoteModelsFormat() {
        // All premium remote models should start with "openrouter:" prefix
        for model in RecommendedModels.premiumRemoteModels {
            #expect(model.hasPrefix("openrouter:"), "Model \(model) should have openrouter prefix")
        }

        // Should have at least 4 premium models
        #expect(RecommendedModels.premiumRemoteModels.count >= 4)
    }

    @Test("All remote models should combine free and premium")
    func testAllRemoteModelsCombination() {
        let expectedCount = RecommendedModels.freeRemoteModels.count + RecommendedModels.premiumRemoteModels.count
        #expect(RecommendedModels.allRemoteModels.count == expectedCount)

        // Free models should be first
        for freeModel in RecommendedModels.freeRemoteModels {
            #expect(RecommendedModels.allRemoteModels.contains(freeModel))
        }

        // Premium models should also be included
        for premiumModel in RecommendedModels.premiumRemoteModels {
            #expect(RecommendedModels.allRemoteModels.contains(premiumModel))
        }
    }

    @Test("Free remote models should end with :free suffix")
    func testFreeRemoteModelsSuffix() {
        // Free models typically end with :free
        let modelsWithFreeSuffix = RecommendedModels.freeRemoteModels.filter { $0.hasSuffix(":free") }
        #expect(modelsWithFreeSuffix.count == RecommendedModels.freeRemoteModels.count)
    }

    @Test("Premium remote models should not have :free suffix")
    func testPremiumRemoteModelsNoFreeSuffix() {
        // Premium models should NOT end with :free
        for model in RecommendedModels.premiumRemoteModels {
            #expect(!model.hasSuffix(":free"), "Premium model \(model) should not have :free suffix")
        }
    }

    @Test("Remote models should have no duplicates")
    func testRemoteModelsNoDuplicates() {
        let uniqueModels = Set(RecommendedModels.allRemoteModels)
        #expect(uniqueModels.count == RecommendedModels.allRemoteModels.count)
    }
}
