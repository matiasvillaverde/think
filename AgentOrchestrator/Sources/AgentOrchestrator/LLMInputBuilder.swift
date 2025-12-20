import Abstractions
import ContextBuilder
import Database
import Foundation
import OSLog

/// Builder for creating LLMInput from Chat configuration
internal struct LLMInputBuilder {
    private let chat: UUID
    private let model: SendableModel
    private let database: DatabaseProtocol
    private let contextBuilder: ContextBuilding
    private static let logger: Logger = Logger(
        subsystem: "AgentOrchestrator",
        category: "LLMInputBuilder"
    )

    internal init(
        chat: UUID,
        model: SendableModel,
        database: DatabaseProtocol,
        contextBuilder: ContextBuilding
    ) {
        self.chat = chat
        self.model = model
        self.database = database
        self.contextBuilder = contextBuilder
    }

    /// Builds an LLMInput using the chat's configuration and model-specific settings
    /// - Parameters:
    ///   - context: The prepared context string
    /// - Returns: A configured LLMInput with proper sampling parameters and limits
    internal func build(context: String) async throws -> LLMInput {
        // Get configuration and stop sequences
        let llmConfig: SendableLLMConfiguration = try await database.read(
            ChatCommands.GetLanguageModelConfiguration(chatId: chat, prompt: context)
        )

        // Get stop sequences from context builder
        let stopSequences: [String] = Array(await contextBuilder.getStopSequences(model: model))

        logStopSequences(stopSequences, for: model)

        // Build and return input
        let input: LLMInput = LLMInput(
            context: context,
            images: [],
            videoURLs: [],
            sampling: buildSampling(from: llmConfig, stopSequences: stopSequences),
            limits: buildLimits(from: llmConfig)
        )

        logSamplingParameters(input)
        return input
    }

    private func buildSampling(
        from config: SendableLLMConfiguration,
        stopSequences: [String]
    ) -> SamplingParameters {
        SamplingParameters(
            temperature: config.temperature,
            topP: config.topP,
            topK: nil,
            repetitionPenalty: config.repetitionPenalty,
            frequencyPenalty: nil,
            presencePenalty: nil,
            repetitionPenaltyRange: config.repetitionContextSize,
            seed: nil,
            stopSequences: stopSequences
        )
    }

    private func buildLimits(from config: SendableLLMConfiguration) -> ResourceLimits {
        ResourceLimits(
            maxTokens: config.maxTokens,
            maxTime: nil,
            collectDetailedMetrics: true
        )
    }

    private func logStopSequences(_ stopSequences: [String], for model: SendableModel) {
        Self.logger.info("Building LLMInput for model: \(model.id)")
        Self.logger.info("Model architecture: \(String(describing: model.architecture))")
        Self.logger.info("Stop sequences retrieved: \(stopSequences.count) sequences")
        for (index, sequence) in stopSequences.enumerated() {
            Self.logger.info("Stop sequence [\(index)]: '\(sequence)'")
        }
    }

    private func logSamplingParameters(_ input: LLMInput) {
        Self.logger.info("LLMInput built with sampling parameters:")
        Self.logger.info("  Temperature: \(input.sampling.temperature)")
        Self.logger.info("  TopP: \(input.sampling.topP)")
        if let repetitionPenalty = input.sampling.repetitionPenalty {
            Self.logger.info("  RepetitionPenalty: \(repetitionPenalty)")
        }
        Self.logger.info("  MaxTokens: \(input.limits.maxTokens)")
    }
}
