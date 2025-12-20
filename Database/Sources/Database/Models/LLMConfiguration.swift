import Foundation
import SwiftData
import Abstractions
import DataAssets

@Model
@DebugDescription
public final class LLMConfiguration: Identifiable, Equatable {
    // MARK: - Identity

    /// A unique identifier for the entity.
    @Attribute(.unique)
    public private(set) var id: UUID = UUID()

    /// The creation date of the entity.
    @Attribute()
    public private(set) var createdAt: Date = Date()

    // MARK: - Metadata

    /// Instruction given to the LLM to guide its answers (system prompt).
    @Attribute()
    public private(set) var systemInstruction: SystemInstruction = SystemInstruction.englishAssistant

    @Relationship(deleteRule: .nullify)
    public internal(set) var personality: Personality?

    /// The type of algorithm to build the context
    @Attribute()
    public private(set) var contextStrategy: ContextStrategy

    /// The step size for the model's token generation.
    @Attribute()
    public private(set) var stepSize: Int

    /// The temperature setting for generation; higher values = more randomness.
    @Attribute()
    public private(set) var temperature: Float

    /// The top-p (nucleus sampling) parameter, controlling the “safe zone” of tokens.
    @Attribute()
    public private(set) var topP: Float

    /// Optional repetition penalty factor.
    @Attribute()
    public private(set) var repetitionPenalty: Float?

    /// The context size to consider for repetition penalty.
    @Attribute()
    public private(set) var repetitionContextSize: Int

    /// The maximum tokens the model is allowed to generate.
    @Attribute()
    public private(set) var maxTokens: Int

    /// The maximum tokens the model can digest
    @Attribute()
    public private(set) var maxPrompt: Int

    @Attribute()
    public private(set) var prefillStepSize: Int

    /// Reasoning level for Harmony format models (low, medium, high, automatic)
    @Attribute()
    public var reasoningLevel: String?

    /// Whether to include current date in context (nil = automatic)
    @Attribute()
    public var includeCurrentDate: Bool? // swiftlint:disable:this discouraged_optional_boolean

    /// Custom knowledge cutoff date override (format: YYYY-MM)
    @Attribute()
    public var knowledgeCutoffDate: String?

    /// Override for current date (format: YYYY-MM-DD) - used for testing
    @Attribute()
    public var currentDateOverride: String?

    // MARK: - Initializers

    init(
        systemInstruction: SystemInstruction,
        contextStrategy: ContextStrategy,
        stepSize: Int,
        temperature: Float,
        topP: Float,
        repetitionPenalty: Float?,
        repetitionContextSize: Int,
        maxTokens: Int,
        maxPrompt: Int,
        prefillStepSize: Int,
        personality: Personality? = nil,
        reasoningLevel: String? = nil,
        includeCurrentDate: Bool? = true, // swiftlint:disable:this discouraged_optional_boolean
        knowledgeCutoffDate: String? = nil,
        currentDateOverride: String? = nil
    ) {
        self.systemInstruction = systemInstruction
        self.stepSize = stepSize
        self.temperature = temperature
        self.topP = topP
        self.repetitionPenalty = repetitionPenalty
        self.repetitionContextSize = repetitionContextSize
        self.maxTokens = maxTokens
        self.contextStrategy = contextStrategy
        self.maxPrompt = maxPrompt
        self.prefillStepSize = prefillStepSize
        self.personality = personality
        self.reasoningLevel = reasoningLevel
        self.includeCurrentDate = includeCurrentDate
        self.knowledgeCutoffDate = knowledgeCutoffDate
        self.currentDateOverride = currentDateOverride
    }

    public static func new(personality: Personality) -> LLMConfiguration {
        .init(
            systemInstruction: personality.systemInstruction,
            contextStrategy: .allMessages,
            stepSize: 512,
            temperature: 0.7,
            topP: 1.0,
            repetitionPenalty: nil,
            repetitionContextSize: 20,
            maxTokens: 10240,
            maxPrompt: 10240,
            prefillStepSize: 512,
            personality: personality
        )
    }

    /// A convenience default configuration for quick creation.
    public static var `default`: LLMConfiguration {
        LLMConfiguration(
            systemInstruction: SystemInstruction.englishAssistant,
            contextStrategy: ContextStrategy.allMessages,
            stepSize: 512,
            temperature: 0.7,
            topP: 1.0,
            repetitionPenalty: nil,
            repetitionContextSize: 20,
            maxTokens: 10240,
            maxPrompt: 10240,
            prefillStepSize: 512
        )
    }

    func copy() -> LLMConfiguration {
        .init(
            systemInstruction: systemInstruction.copy(),
            contextStrategy: contextStrategy,
            stepSize: stepSize,
            temperature: temperature,
            topP: topP,
            repetitionPenalty: repetitionPenalty,
            repetitionContextSize: repetitionContextSize,
            maxTokens: maxTokens,
            maxPrompt: maxPrompt,
            prefillStepSize: prefillStepSize,
            personality: personality,
            reasoningLevel: reasoningLevel,
            includeCurrentDate: includeCurrentDate,
            knowledgeCutoffDate: knowledgeCutoffDate,
            currentDateOverride: currentDateOverride
        )
    }

    func toSendable(prompt: String) -> SendableLLMConfiguration {
        SendableLLMConfiguration(
            prompt: prompt,
            maxTokens: maxTokens,
            prefillStepSize: prefillStepSize,
            temperature: temperature,
            topP: topP,
            repetitionPenalty: repetitionPenalty,
            repetitionContextSize: repetitionContextSize
        )
    }
}

public enum ContextStrategy: String, Codable {
    case allMessages
    case messages // Add only relevant messages
    case files // Add chunks of files that are relevant
    case messagesAndFiles
    case webSearch
}

extension LLMConfiguration {
    @MainActor public static var previews: [LLMConfiguration] = {
        [LLMConfiguration.preview]
    }()

    @MainActor public static var preview: LLMConfiguration = {
        LLMConfiguration(
            systemInstruction: .englishAssistant,
            contextStrategy: .allMessages,
            stepSize: 10,
            temperature: 0.4,
            topP: 10,
            repetitionPenalty: nil,
            repetitionContextSize: 100,
            maxTokens: 1000,
            maxPrompt: 800,
            prefillStepSize: 512
        )
    }()
}
