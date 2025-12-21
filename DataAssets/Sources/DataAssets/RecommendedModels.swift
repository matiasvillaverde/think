import Foundation

/// Single source of truth for recommended models across the application
///
/// This contains curated lists of high-quality models that work well
/// on various device configurations and use cases.
public struct RecommendedModels {
    // MARK: - Tier-specific model lists

    /// Models for 4GB memory tier
    public static let fourGBModels: [String] = [
        "mlx-community/gemma-3-1b-it-qat-4bit",
        "mlx-community/Qwen3-0.6B-4bit",
        "mlx-community/Qwen3-1.7B-4bit",
        "mlx-community/DeepSeek-R1-Distill-Qwen-1.5B-4bit",
        "mlx-community/Llama-3.2-1B-Instruct-4bit",
        "mlx-community/Phi-4-mini-instruct-4bit",
        "mlx-community/SmolLM-1.7B-Instruct-4bit",
        "lmstudio-community/LFM2-1.2B-MLX-bf16",
        "lmstudio-community/SmolLM3-3B-MLX-8bit"
    ]

    /// Models for 8GB memory tier
    public static let eightGBModels: [String] = [
        "mlx-community/Qwen3-4B-8bit",
        "mlx-community/gemma-3-4b-it-qat-4bit",
        "mlx-community/DeepSeek-R1-0528-Qwen3-8B-4bit",
        "mlx-community/Llama-3.2-3B-Instruct-4bit",
        "mlx-community/Phi-3-mini-4k-instruct-4bit",
        "mlx-community/Mistral-7B-Instruct-v0.3-4bit",
        "lmstudio-community/DeepSeek-R1-0528-Qwen3-8B-MLX-4bit",
        "mlx-community/Qwen2.5-7B-Instruct-4bit"
    ]

    /// Models for 16GB memory tier
    public static let sixteenGBModels: [String] = [
        "mlx-community/Qwen3-8B-4bit",
        "mlx-community/Qwen3-14B-4bit",
        "mlx-community/gemma-3n-E4B-it-4bit",
        "mlx-community/DeepSeek-R1-Distill-Qwen-7B-4bit",
        "mlx-community/Meta-Llama-3.1-8B-Instruct-4bit",
        "mlx-community/Phi-4-mini-reasoning-4bit",
        "mlx-community/GLM-4-9B-0414-4bit",
        "lmstudio-community/DeepSeek-R1-0528-Qwen3-8B-MLX-8bit"
    ]

    /// Models for 32GB memory tier
    public static let thirtyTwoGBModels: [String] = [
        "mlx-community/gemma-3-12b-it-qat-4bit",
        "mlx-community/Qwen3-30B-A3B-4bit",
        "mlx-community/DeepSeek-R1-Distill-Qwen-14B-4bit",
        "mlx-community/Llama-4-Scout-17B-16E-Instruct-4bit",
        "mlx-community/Phi-4-mini-instruct-8bit",
        "mlx-community/GLM-4-32B-0414-4bit",
        "lmstudio-community/Qwen3-30B-A3B-Instruct-2507-MLX-4bit"
    ]

    /// Models for 64GB memory tier
    public static let sixtyFourGBModels: [String] = [
        "mlx-community/Qwen3-30B-A3B-Instruct-2507-4bit",
        "mlx-community/gemma-3-27b-it-qat-4bit",
        "mlx-community/Qwen3-235B-A22B-4bit",
        "mlx-community/DeepSeek-R1-0528-4bit",
        "mlx-community/Llama-3.3-70B-Instruct-4bit",
        "mlx-community/Phi-3.5-mini-instruct-4bit",
        "mlx-community/GLM-4.5-Air-2bit"
    ]

    /// Models for 128GB+ memory tier
    public static let oneTwentyEightGBPlusModels: [String] = [
        "mlx-community/gemma-3-27b-it-qat-bf16",
        "mlx-community/Qwen3-235B-A22B-8bit",
        "mlx-community/DeepSeek-V3-4bit",
        "mlx-community/Meta-Llama-3-70B-Instruct-4bit",
        "mlx-community/Phi-4-4bit",
        "mlx-community/GLM-4.5-Air-4bit",
        "mlx-community/GLM-4.5-Air-6bit",
        "mlx-community/GLM-4.5-Air-8bit",
        "lmstudio-community/Qwen3-Coder-480B-A35B-Instruct-MLX-4bit",
        "lmstudio-community/Qwen3-Coder-480B-A35B-Instruct-MLX-6bit",
        "lmstudio-community/Qwen3-Coder-480B-A35B-Instruct-MLX-8bit"
    ]

    /// Default recommended language models (all tiers combined)
    /// These models are selected for their balance of quality, performance, and device compatibility
    public static let defaultLanguageModels: [String] =
        fourGBModels + eightGBModels + sixteenGBModels +
        thirtyTwoGBModels + sixtyFourGBModels + oneTwentyEightGBPlusModels

    // MARK: - Remote/Cloud Models

    /// Free remote models available through OpenRouter
    /// These models don't require local RAM and run on cloud infrastructure
    public static let freeRemoteModels: [String] = [
        "openrouter:google/gemma-3n-e2b-it:free",
        "openrouter:meta-llama/llama-3.2-3b-instruct:free",
        "openrouter:deepseek/deepseek-r1-0528:free",
        "openrouter:qwen/qwen3-coder:free",
        "openrouter:moonshotai/kimi-k2:free"
    ]

    /// Premium remote models available through OpenRouter (requires API credits)
    public static let premiumRemoteModels: [String] = [
        "openrouter:anthropic/claude-3.5-sonnet",
        "openrouter:openai/gpt-4o",
        "openrouter:google/gemini-pro",
        "openrouter:meta-llama/llama-3.1-405b-instruct"
    ]

    /// All remote models (free + premium)
    public static let allRemoteModels: [String] = freeRemoteModels + premiumRemoteModels

    /// Default recommended image generation models
    /// These models are optimized for Apple devices and provide good image quality
    public static let defaultImageModels: [String] = [
        // Top 5
        "coreml-community/coreml-juggernautXL-v6_SDXL_8-bit",
        "coreml-community/coreml-ChilloutMix",
        "coreml-community/coreml-dreamshaper-4-and-5",
        "coreml-community/coreml-animagine-xl-3.1",
        "coreml-community/coreml-realisticVision-v51VAE_cn",

        // Honorable Mentions
        "coreml-community/coreml-ReV-Animated",
        "coreml-community/coreml-majicmixRealistic_v6_cn",
        "coreml-community/coreml-Inkpunk-Diffusion",
        "coreml-community/coreml-anything-v4.0",
        "coreml-community/coreml-realisticVision-v20"
    ]

    /// All recommended models combined
    public static let allRecommendedModels = defaultLanguageModels + defaultImageModels

    /// Models that should always be included regardless of memory tier
    public static let alwaysIncludeModels: Set<String> = [
        "mlx-community/Qwen3-1.7B-4bit",  // Extremely efficient model suitable for all devices,
        "lmstudio-community/Qwen3-4B-Instruct-2507-GGUF",
        "lmstudio-community/gpt-oss-20b-GGUF",
        "lmstudio-community/gemma-3-12b-it-GGUF"
    ]

    /// Types of recommendations available for models
    public enum RecommendationType: String, CaseIterable {
        case fast = "recommended_fast"
        case complexTasks = "recommended_complex_tasks"

        /// Localized display name for the recommendation type
        public var displayName: String {
            switch self {
            case .fast:
                return "Recommended Fast"
            case .complexTasks:
                return "Recommended for Complex Tasks"
            }
        }
    }

    /// Check if a model ID is in the recommended list
    /// - Parameter modelId: Model ID to check
    /// - Returns: True if model is recommended
    public static func isRecommended(_ modelId: String) -> Bool {
        allRecommendedModels.contains(modelId)
    }

    /// Get model type from model ID
    /// - Parameter modelId: Model ID to analyze
    /// - Returns: Estimated model type based on ID patterns
    public static func getModelType(for modelId: String) -> ModelType {
        if modelId.contains("stable-diffusion") || modelId.contains("coreml") {
            return .image
        }
        return .language
    }

    /// Model type classification
    public enum ModelType {
        case language
        case image
    }

    /// Memory tier enumeration for categorizing device memory
    public enum MemoryTier: CaseIterable {
        case fourGB
        case eightGB
        case sixteenGB
        case thirtyTwoGB
        case sixtyFourGB
        case oneTwentyEightGBPlus

        /// The memory threshold for this tier in bytes
        var threshold: UInt64 {
            switch self {
            case .fourGB: return 4 * MemorySize.GB
            case .eightGB: return 8 * MemorySize.GB
            case .sixteenGB: return 16 * MemorySize.GB
            case .thirtyTwoGB: return 32 * MemorySize.GB
            case .sixtyFourGB: return 64 * MemorySize.GB
            case .oneTwentyEightGBPlus: return 128 * MemorySize.GB
            }
        }

        /// Get models for this specific tier
        var models: [String] {
            switch self {
            case .fourGB: return fourGBModels
            case .eightGB: return eightGBModels
            case .sixteenGB: return sixteenGBModels
            case .thirtyTwoGB: return thirtyTwoGBModels
            case .sixtyFourGB: return sixtyFourGBModels
            case .oneTwentyEightGBPlus: return oneTwentyEightGBPlusModels
            }
        }

        /// Get the start index for models in this tier (for backward compatibility)
        var modelStartIndex: Int {
            switch self {
            case .fourGB: return 0
            case .eightGB: return fourGBModels.count
            case .sixteenGB: return fourGBModels.count + eightGBModels.count
            case .thirtyTwoGB: return fourGBModels.count + eightGBModels.count + sixteenGBModels.count
            case .sixtyFourGB:
                return fourGBModels.count + eightGBModels.count + sixteenGBModels.count + thirtyTwoGBModels.count
            case .oneTwentyEightGBPlus:
                return fourGBModels.count + eightGBModels.count + sixteenGBModels.count + thirtyTwoGBModels.count + sixtyFourGBModels.count
            }
        }

        /// Get the end index (exclusive) for models in this tier (for backward compatibility)
        var modelEndIndex: Int {
            switch self {
            case .fourGB: return fourGBModels.count
            case .eightGB: return fourGBModels.count + eightGBModels.count
            case .sixteenGB: return fourGBModels.count + eightGBModels.count + sixteenGBModels.count
            case .thirtyTwoGB: return fourGBModels.count + eightGBModels.count + sixteenGBModels.count + thirtyTwoGBModels.count
            case .sixtyFourGB:
                return fourGBModels.count + eightGBModels.count + sixteenGBModels.count + thirtyTwoGBModels.count + sixtyFourGBModels.count
            case .oneTwentyEightGBPlus: return defaultLanguageModels.count
            }
        }

        /// Check if this tier includes models from another tier
        public func includesModelsFromTier(_ other: MemoryTier) -> Bool {
            guard let selfIndex = MemoryTier.allCases.firstIndex(of: self),
                  let otherIndex = MemoryTier.allCases.firstIndex(of: other) else {
                return false
            }
            return selfIndex >= otherIndex
        }
    }

    /// Get the memory tier for a given amount of memory
    /// - Parameter memory: Available memory in bytes
    /// - Returns: The appropriate memory tier
    public static func getMemoryTier(for memory: UInt64) -> MemoryTier {
        let memoryInGB = Double(memory) / Double(MemorySize.GB)

        // Use midpoint logic: if memory is above the midpoint between two tiers,
        // assign it to the higher tier
        if memoryInGB >= 96.0 { // Midpoint between 64GB and 128GB
            return .oneTwentyEightGBPlus
        }
        if memoryInGB >= 48.0 { // Midpoint between 32GB and 64GB
            return .sixtyFourGB
        }
        if memoryInGB >= 24.0 { // Midpoint between 16GB and 32GB
            return .thirtyTwoGB
        }
        if memoryInGB >= 12.0 { // Midpoint between 8GB and 16GB
            return .sixteenGB
        }
        if memoryInGB >= 6.0 { // Midpoint between 4GB and 8GB
            return .eightGB
        }
        if memoryInGB >= 3.6 { // 90% of 4GB (tolerance for 4GB devices)
            return .fourGB
        }
        // Very low memory still gets 4GB tier
        return .fourGB
    }

    /// Get language models appropriate for a device's memory
    /// - Parameter memory: Available memory in bytes
    /// - Returns: Array of model IDs suitable for the device
    public static func getLanguageModels(forMemory memory: UInt64) -> [String] {
        let tier = getMemoryTier(for: memory)
        var models: [String] = []

        // Add all models from lower tiers and the current tier
        for currentTier in MemoryTier.allCases {
            if tier.includesModelsFromTier(currentTier) {
                let startIndex = currentTier.modelStartIndex
                let endIndex = currentTier.modelEndIndex
                models.append(contentsOf: Array(defaultLanguageModels[startIndex..<endIndex]))
            }
        }

        return models
    }

    /// Get language models for the exact memory tier (not including lower tiers)
    /// Always includes models from alwaysIncludeModels
    public static func getLanguageModelsForExactTier(forMemory memory: UInt64) -> [String] {
        let tier = getMemoryTier(for: memory)
        var models: Set<String> = []

        // Add models from exact tier only
        models.formUnion(tier.models)

        // Always include these models
        models.formUnion(alwaysIncludeModels)

        return Array(models)
    }

    /// Get image models appropriate for a device's memory
    /// - Parameter memory: Available memory in bytes
    /// - Returns: Array of image model IDs suitable for the device
    public static func getImageModels(forMemory memory: UInt64) -> [String] {
        // For image models, we return all if device has at least 4GB
        // Most image models require 3-4GB of memory
        let memoryInGB = Double(memory) / Double(MemorySize.GB)
        if memoryInGB >= 3.5 {
            return defaultImageModels
        }
        // For very low memory devices, return only the most efficient models
        return Array(defaultImageModels.prefix(3))
    }

    /// Get the recommended model for a specific memory tier
    /// - Parameter tier: The memory tier
    /// - Returns: The recommended model ID for this tier, or nil if none
    public static func getRecommendedModel(for tier: MemoryTier) -> String? {
        switch tier {
        case .fourGB:
            return "mlx-community/Qwen3-1.7B-4bit"
        case .eightGB:
            return "mlx-community/Qwen3-4B-8bit"
        case .sixteenGB:
            return "mlx-community/Qwen3-14B-4bit"
        case .thirtyTwoGB:
            return "mlx-community/Qwen3-30B-A3B-4bit"
        case .sixtyFourGB:
            return "mlx-community/Qwen3-30B-A3B-Instruct-2507-4bit"
        case .oneTwentyEightGBPlus:
            return "mlx-community/Qwen3-235B-A22B-8bit"
        }
    }

    /// Check if a model is the recommended model for any tier
    /// - Parameter modelId: The model ID to check
    /// - Returns: True if the model is recommended for any tier
    public static func isRecommendedForTier(_ modelId: String) -> Bool {
        for tier in MemoryTier.allCases {
            if getRecommendedModel(for: tier) == modelId {
                return true
            }
        }
        return false
    }

    /// Get the recommendation type for a specific model
    /// - Parameter modelId: The model ID to check
    /// - Returns: The recommendation type if the model is recommended, nil otherwise
    public static func getRecommendationType(for modelId: String) -> RecommendationType? {
        if alwaysIncludeModels.contains(modelId) {
            return .fast
        }

        if isRecommendedForTier(modelId) {
            return .complexTasks
        }

        return nil
    }

    /// Check if a model is recommended for fast tasks
    /// - Parameter modelId: The model ID to check
    /// - Returns: True if the model is recommended for fast tasks
    public static func isRecommendedForFastTasks(_ modelId: String) -> Bool {
        alwaysIncludeModels.contains(modelId)
    }

    /// Check if a model is recommended for complex tasks
    /// - Parameter modelId: The model ID to check
    /// - Returns: True if the model is recommended for complex tasks
    public static func isRecommendedForComplexTasks(_ modelId: String) -> Bool {
        isRecommendedForTier(modelId) && !alwaysIncludeModels.contains(modelId)
    }
}

// MARK: - Memory Categories

/// Memory categories for device classification
public enum MemoryCategory {
    case low      // 8GB and below
    case medium   // 8GB to 16GB
    case high     // 16GB and above

    init(availableMemory: UInt64) {
        switch availableMemory {
        case 0..<(8 * 1024 * 1024 * 1024):
            self = .low
        case (8 * 1024 * 1024 * 1024)..<(16 * 1024 * 1024 * 1024):
            self = .medium
        default:
            self = .high
        }
    }
}

// MARK: - Memory Utilities

extension RecommendedModels {
    /// Memory size helpers
    public struct MemorySize {
        public static let gigabyte: UInt64 = 1024 * 1024 * 1024
        // Alias for backward compatibility
        public static let GB: UInt64 = gigabyte

        public static func gigabytes(_ value: UInt64) -> UInt64 {
            value * gigabyte
        }

        public static func formatBytes(_ bytes: UInt64) -> String {
            let formatter = ByteCountFormatter()
            formatter.countStyle = .memory
            return formatter.string(fromByteCount: Int64(bytes))
        }
    }
}
