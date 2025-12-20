import Foundation

/// Factory responsible for creating and managing model tags
internal class TagFactory {
    // MARK: - Tag Constants

    /// Text generation capability
    internal let textGeneration = String(
        localized: "Text generation",
        bundle: .module,
        comment: "Ability to generate text based on prompts"
    )

    /// Chat/conversational capability
    internal let chat = String(
        localized: "Chat",
        bundle: .module,
        comment: "Conversational ability with users"
    )

    /// Reasoning capability
    internal let reasoning = String(
        localized: "Reasoning",
        bundle: .module,
        comment: "Logical thinking and problem-solving capability"
    )

    /// Summarization capability
    internal let summarization = String(
        localized: "Summarization",
        bundle: .module,
        comment: "Ability to summarize longer text"
    )

    /// Code generation capability
    internal let code = String(
        localized: "Code",
        bundle: .module,
        comment: "Programming and code generation ability"
    )

    /// Mathematical problem-solving capability
    internal let math = String(
        localized: "Math",
        bundle: .module,
        comment: "Mathematical problem-solving capability"
    )

    /// Tool use capability
    internal let toolUse = String(
        localized: "Tool use",
        bundle: .module,
        comment: "Ability to use external tools and APIs"
    )

    /// RAG (Retrieval Augmented Generation) capability
    internal let rag = String(
        localized: "RAG",
        bundle: .module,
        comment: "Retrieval Augmented Generation capability"
    )

    /// Function calling capability
    internal let functionCalling = String(
        localized: "Function calling",
        bundle: .module,
        comment: "Ability to call external functions"
    )

    /// Multi-step agents capability
    internal let multiStepAgents = String(
        localized: "Multi-step agents",
        bundle: .module,
        comment: "Ability to perform multi-step reasoning and planning"
    )

    /// Lightweight inference capability
    internal let lightweightInference = String(
        localized: "Lightweight inference",
        bundle: .module,
        comment: "Optimized for low-resource environments"
    )

    /// Multilingual capability
    internal let multilingual = String(
        localized: "Multilingual",
        bundle: .module,
        comment: "Support for multiple human languages"
    )

    internal let videoUnderstanding = String(
        localized: "Video understanding",
        bundle: .module,
        comment: "Support for understanding videos"
    )

    internal let visualAnalysis = String(
        localized: "Image understanding",
        bundle: .module,
        comment: "Support for understanding images"
    )

    /// Code generation capability
    internal let codeGeneration = String(
        localized: "Code generation",
        bundle: .module,
        comment: "Ability to generate programming code"
    )

    /// Mathematical reasoning capability
    internal let mathematicalReasoning = String(
        localized: "Mathematical reasoning",
        bundle: .module,
        comment: "Advanced math problem-solving capability"
    )

    /// Code completion capability
    internal let codeCompletion = String(
        localized: "Code completion",
        bundle: .module,
        comment: "Ability to complete partial code snippets"
    )

    /// Code insertion capability
    internal let codeInsertion = String(
        localized: "Code insertion",
        bundle: .module,
        comment: "Ability to insert code within existing snippets"
    )

    /// Image generation capability
    internal let imageGeneration = String(
        localized: "Image generation",
        bundle: .module,
        comment: "Ability to create images from text descriptions"
    )

    // MARK: - Tag Set Methods

    /// Returns standard tags for chat models
    internal func chatModelTags() -> [String] {
        [
            textGeneration,
            chat,
            reasoning,
            summarization
        ]
    }

    /// Returns tags for code-focused models
    internal func codeModelTags() -> [String] {
        [
            textGeneration,
            reasoning,
            code
        ]
    }

    /// Returns tags for math-focused models
    internal func mathModelTags() -> [String] {
        [
            textGeneration,
            math,
            reasoning
        ]
    }

    /// Returns tags for image generation models
    internal func imageModelTags() -> [String] {
        [imageGeneration]
    }

    /// Returns tags for advanced reasoning models
    internal func advancedReasoningModelTags() -> [String] {
        [
            textGeneration,
            reasoning,
            functionCalling,
            multilingual
        ]
    }

    /// Returns tags for code specialized models
    internal func codeSpecializedModelTags() -> [String] {
        [
            codeGeneration,
            mathematicalReasoning,
            codeCompletion,
            codeInsertion
        ]
    }
}