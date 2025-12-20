import Abstractions
import Foundation

/// Factory for creating model-specific label configurations
/// Provides type-safe methods for different label compositions
internal enum LabelFactory {
    /// Creates ChatML labels for models using ChatML format
    /// This includes Yi, SmolLM, Gemma, DeepSeek, ChatGLM, Phi, Phi4
    internal static func createChatMLLabels() -> ChatMLLabels {
        ChatMLLabels()
    }

    /// Creates Harmony labels for Harmony and GPT architectures
    /// Includes channel-based formatting with special tokens
    internal static func createHarmonyLabels() -> HarmonyLabels {
        HarmonyLabels()
    }

    /// Creates Qwen labels with thinking command support
    internal static func createQwenLabels() -> QwenLabels {
        QwenLabels()
    }

    /// Creates Llama3 labels with Python environment support
    internal static func createLlama3Labels() -> Llama3Labels {
        Llama3Labels()
    }

    /// Creates Mistral labels with custom [INST] format
    internal static func createMistralLabels() -> MistralLabels {
        MistralLabels()
    }

    /// Creates labels for a specific architecture
    /// Returns the appropriate label implementation for each model type
    /// - Throws: `LabelError.unsupportedArchitecture` for non-conversational models
    internal static func createLabels(
        for architecture: Architecture
    ) throws -> any StopSequenceLabels {
        switch architecture {
        case .harmony, .gpt:
            return createHarmonyLabels()

        case .qwen:
            return createQwenLabels()

        case .llama:
            return createLlama3Labels()

        case .mistral, .mixtral:
            return createMistralLabels()

        case .yi, .smol, .gemma, .deepseek, .chatglm, .phi, .phi4:
            return createChatMLLabels()

        case .falcon, .baichuan:
            // These use simpler formats but can work with ChatML structure
            return createChatMLLabels()

        case .bert, .t5, .stableDiffusion, .flux, .whisper, .unknown:
            // Non-conversational models are not supported
            throw LabelError.unsupportedArchitecture(architecture)
        }
    }

    /// Creates ChatML labels for a specific model
    /// Type-safe method that guarantees ChatML protocol conformance
    internal static func createChatMLLabels(for model: SendableModel) -> ChatMLLabels? {
        switch model.architecture {
        case .yi, .smol, .gemma, .deepseek, .chatglm, .phi, .phi4, .falcon, .baichuan:
            return createChatMLLabels()

        default:
            return nil
        }
    }

    /// Creates Harmony labels for a specific model
    /// Type-safe method that guarantees Harmony protocol conformance
    internal static func createHarmonyLabels(for model: SendableModel) -> HarmonyLabels? {
        switch model.architecture {
        case .harmony, .gpt:
            return createHarmonyLabels()

        default:
            return nil
        }
    }

    /// Creates Qwen labels for a specific model
    /// Type-safe method that guarantees Qwen protocol conformance
    internal static func createQwenLabels(for model: SendableModel) -> QwenLabels? {
        switch model.architecture {
        case .qwen:
            return createQwenLabels()

        default:
            return nil
        }
    }

    /// Creates Llama3 labels for a specific model
    /// Type-safe method that guarantees Llama3 protocol conformance
    internal static func createLlama3Labels(for model: SendableModel) -> Llama3Labels? {
        switch model.architecture {
        case .llama:
            return createLlama3Labels()

        default:
            return nil
        }
    }

    /// Creates Mistral labels for a specific model
    /// Type-safe method that guarantees Mistral protocol conformance
    internal static func createMistralLabels(for model: SendableModel) -> MistralLabels? {
        switch model.architecture {
        case .mistral, .mixtral:
            return createMistralLabels()

        default:
            return nil
        }
    }
}
